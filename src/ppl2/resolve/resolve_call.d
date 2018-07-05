module ppl2.resolve.resolve_call;

import ppl2.internal;
///
/// Resolve a call.                                                                    
///                                                                                    
/// - The target may be either a Function or a Variable (of function ptr type).        
/// - The target may not be in the same module.                                        
///                                                                                    
/// - If we find a Function match that is a proxy for one or more external functions of
///   a given name then we need to pull in the external module.                        
///
final class CallResolver {
private:
    Module module_;
    ModuleResolver moduleResolver;
    Array!Callable overloads;
public:
    this(ModuleResolver moduleResolver) {
        this.module_        = moduleResolver.module_;
        this.moduleResolver = moduleResolver;
        this.overloads      = new Array!Callable;
    }

    Callable find(string name, Type[] argTypes, ASTNode node) {
        overloads.clear();

        if(find(name, node, overloads)) {
            filterOverloads(argTypes, overloads);

            if(overloads.length==0) {
                throw new CompilerError(Err.FUNCTION_NOT_FOUND, node,
                    "Function %s not found".format(name));
            }
            if(overloads.length > 1) {
                throw new CompilerError(Err.AMBIGUOUS_CALL, node,
                    "Ambiguous call");
            }

            return overloads[0];
        }
        return null;
    }
    ///
    /// Find any function or variable that matches the given function name.
    /// Return true - if results contains the full overload set and all types are known,
    ///       false - if we are waiting for imports or some types are waiting to be known.
    ///
    bool find(string name, ASTNode node, Array!Callable results, bool ready = true) {
        auto nid = node.id();

        if(nid==NodeID.MODULE) {
            /// Check all module level variables/functions
            foreach(n; node.children) {
                checkForFunction(name, n, results, ready) ||
                checkForVariable(name, n, results, ready);
            }
            return ready;
        }

        if(nid==NodeID.ANON_STRUCT) {
            /// Check all struct level variables
            foreach(n; node.children) {
                checkForFunction(name, n, results, ready) ||
                checkForVariable(name, n, results, ready);
            }

            /// Skip to module level scope
            return find(name, node.getModule(), results, ready);
        }

        if(nid==NodeID.LITERAL_FUNCTION) {

            /// If this is not a closure
            if(!node.as!LiteralFunction.isClosure) {
                /// Go to containing struct if there is one
                auto struct_ = node.getContainingStruct();
                if(struct_) return find(name, struct_, results, ready);
            }

            /// Go to module scope
            return find(name, node.getModule(), results, ready);
        }

        /// Check variables that appear before this in the tree
        foreach(n; node.prevSiblings()) {
            checkForFunction(name, n, results, ready) ||
            checkForVariable(name, n, results, ready);
        }
        /// Recurse up the tree
        return find(name, node.parent, results, ready);
    }
    ///
    /// Filter out all but 1 function/funcptr from the overload set.
    /// Assume all names are the same.
    /// Assume all types are known.
    ///
    void filterOverloads(Type[] argTypes, Array!Callable overloadSet) {
        if(overloadSet.length < 2) return;

        /// More than 1 overload. Filter some out until we have 1 remaining

        log("Selecting from overloadSet:");
        //dd("Unfiltered results:");
        foreach(i, o; overloadSet[]) {
            log("\t[%s] %s", i, o);
            //dd(call, " -> ", o);
        }

        FunctionType type;

        foreach(o; overloadSet[].dup) {
            if(o.isA!Function) {
                type = o.as!Function.getType().getFunctionType;
                assert(type);

                Type[] params = type.paramTypes();
                if(params.length != argTypes.length) {
                    overloadSet.remove(o);
                }

            } else if(o.isA!Variable) {
                type = o.as!Variable.type.getFunctionType();
                if(type is null) {
                    /// This var is not a function ptr so remove it from the overload set
                    overloadSet.remove(o);
                } else {

                }
            } else assert(false, "What am I?");
        }

        //dd("Filtered results:");
        //foreach(i, o; overloadSet[]) {
        //    dd(call, " -> ", o);
        //}
    }
private:
    bool checkForVariable(string name, ASTNode n, Array!Callable results, ref bool ready) {
        auto v = cast(Variable)n;
        if(v && v.name==name) {
            if(v.type.isUnknown) ready = false;
            results.add(v);
            return true;
        }
        return false;
    }
    bool checkForFunction(string name, ASTNode n, Array!Callable results, ref bool ready) {
        auto f = cast(Function)n;
        if(f && f.name==name) {
            if(f.isImport) {
                auto m = PPL2.getModule(f.moduleName);
                if(m && m.isParsed) {
                    auto fns = m.getFunctions(name);
                    if(fns.length==0) {
                        throw new CompilerError(Err.IMPORT_NOT_FOUND, n,
                            "Import %s not found in module %s".format(name, f.moduleName));
                    }
                    foreach(fn; fns) {
                        results.add(fn);

                        if(fn.getType.isUnknown) ready = false;

                        functionRequired(fn.moduleName, name);
                    }
                } else {
                    /// Bring the import in and start parsing it
                    functionRequired(f.moduleName, name);
                    ready = false;
                }
            } else {
                if(f.getType.isUnknown) ready = false;
                results.add(f);
                functionRequired(module_.canonicalName, name);
            }
            return true;
        }
        return false;
    }
}