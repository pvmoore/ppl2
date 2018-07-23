module ppl2.resolve.resolve_call;

import ppl2.internal;
///
/// Resolve a call.                                                                    
///                                                                                    
/// - The target may be either a Function or a Variable (of function ptr type)
/// - The target may be in any module, not just the current one
///                                                                                    
/// - If we find a Function match that is a proxy for one or more external functions of
///   a given name then we need to pull in the external module
///
struct Callable {
    uint id;
    Function func;
    Variable var;

    this(Variable v) {
        this.id   = g_callableID++;
        this.var  = v;
    }
    this(Function f) {
        this.id   = g_callableID++;
        this.func = f;
    }

    bool isVariable()     { return var !is null; }
    bool isFunction()     { return func !is null; }
    string getName()      { return func ? func.name : var.name; }
    Type getType()        { return func ? func.getType : var.type; }
    string[] paramNames() { return getType.getFunctionType.paramNames; }
    Type[] paramTypes()   { return getType.getFunctionType.paramTypes; }
    Module getModule()    { return func ? func.getModule : var.getModule; }
    ASTNode getNode()     { return func ? func : var; }
    bool resultReady()    { return getNode() !is null; }
    bool isStructMember() { return func ? func.isStructMember : var.isStructMember; }

    size_t toHash() const @safe pure nothrow {
        assert(id!=0);
        return id;
    }
    /// Every node is unique
    bool opEquals(ref const Callable o) const @safe  pure nothrow {
        assert(id!=0 && o.id!=0);
        return o.id==id;
    }
}

final class CallResolver {
private:
    Module module_;
    Array!Callable overloads;
public:
    this(Module module_) {
        this.module_   = module_;
        this.overloads = new Array!Callable;
    }

    /// Assume:
    ///     call.argTypes may not yet be known
    ///
    Callable standardFind(Call call) {
        overloads.clear();

        import common : contains;

        if(call.isTemplated && !call.name.contains("<")) {
            /// We can't do anything until the template types are known
            if(!call.templateTypes.areKnown) {
                dd("not ready - template types are not known");
                return CALLABLE_NOT_READY;
            }
            string mangledName = call.name ~ "<" ~ mangle(call.templateTypes) ~ ">";

            dd("looking for", mangledName);

            /// Look for a function with this mangled name even if the params are not resolved yet
            collectOverloadSet(mangledName, call, overloads);
            if(overloads.length==0) {

                extractTemplate(call, mangledName);

                call.name = mangledName;

                dd("not ready");

                return CALLABLE_NOT_READY;
            } else {
                /// It must have been extracted already.
                /// Update the call name and continue
                overloads.clear();
                call.name = mangledName;
            }
        }

        dd("looking for", call.name);

        if(collectOverloadSet(call.name, call, overloads)) {
            dd("ready");

            if(overloads.length==1) {
                /// Return this result as it's the only one and check it later
                /// to make sure the types match
                return overloads[0];
            }

            /// From this point onwards we need the resolved types
            if(!call.argTypes.areKnown) return CALLABLE_NOT_READY;

            filter(call, overloads);

            if(overloads.length==0) {
                string msg;
                if(call.paramNames.length>0) {
                    auto buf = new StringBuffer;
                    foreach(i, n; call.paramNames) {
                        if(i>0) buf.add(", ");
                        buf.add(n).add("=").add(call.argTypes[i].prettyString);
                    }
                    msg = "Function %s(%s) not found".format(call.name, buf.toString);
                } else {
                    msg = "Function %s(%s) not found".format(call.name, call.argTypes.prettyString);
                }
                throw new CompilerError(Err.FUNCTION_NOT_FOUND, call, msg);
            }
            if(overloads.length > 1) {
                throw new AmbiguousCall(call, call.name, call.argTypes, overloads);
            }

            return overloads[0];
        }
        dd("not ready: ", overloads[]);
        return CALLABLE_NOT_READY;
    }
    /// Assume:
    ///     NamedStruct is known
    ///     call.argTypes are known
    ///
    Callable structFind(Call call, NamedStruct ns) {
        AnonStruct struct_ = ns.type;
        assert(ns);
        assert(struct_);

        auto fns      = struct_.getMemberFunctions(call.name);
        auto var      = struct_.getMemberVariable(call.name);
        auto thisType = PtrType.of(ns, 1);

        /// Filter
        overloads.clear();
        foreach(f; fns) overloads.add(Callable(f));
        if(var && var.isFunctionPtr) overloads.add(Callable(var));

        filter(call, overloads);

        if(overloads.length==0) {
            string msg;
            if(call.paramNames.length>0) {
                auto buf = new StringBuffer;
                foreach(i, n; call.paramNames) {
                    if(i>0) buf.add(", ");
                    buf.add(n).add("=").add(call.argTypes[i].prettyString);
                }
                msg = "Strict %s does not have function %s(%s)"
                    .format(ns.getUniqueName, call.name, buf.toString);
            } else {
                msg = "Struct %s does not have function %s(%s)"
                    .format(ns.getUniqueName, call.name, call.argTypes.prettyString);
            }
            throw new CompilerError(Err.FUNCTION_NOT_FOUND, call, msg);

        } else if(overloads.length > 1) {
            throw new AmbiguousCall(call, call.name, call.argTypes(), overloads);
        }

        return overloads[0];
    }
private:
    ///
    /// Find any function or variable that matches the given call name.
    /// Return true - if results contains the full overload set and all types are known,
    ///       false - if we are waiting for imports or some types are waiting to be known.
    ///
    bool collectOverloadSet(string name, ASTNode node, Array!Callable results, bool ready = true) {
        auto nid = node.id();

        if(nid==NodeID.MODULE) {
            /// Check all module level variables/functions
            foreach(n; node.children) {
                check(name, n, results, ready);
            }
            return ready;
        }

        if(nid==NodeID.ANON_STRUCT) {
            /// Check all struct level variables
            foreach(n; node.children) {
                check(name, n, results, ready);
            }

            /// Skip to module level scope
            return collectOverloadSet(name, node.getModule(), results, ready);
        }

        if(nid==NodeID.LITERAL_FUNCTION) {

            /// If this is not a closure
            if(!node.as!LiteralFunction.isClosure) {
                /// Go to containing struct if there is one
                auto struct_ = node.getContainingStruct();
                if(struct_) return collectOverloadSet(name, struct_, results, ready);
            }

            /// Go to module scope
            return collectOverloadSet(name, node.getModule(), results, ready);
        }

        /// Check variables that appear before this in the tree
        foreach(n; node.prevSiblings()) {
            check(name, n, results, ready);
        }
        /// Recurse up the tree
        return collectOverloadSet(name, node.parent, results, ready);
    }
    void check(string name, ASTNode n, Array!Callable results, ref bool ready) {
        auto v    = n.as!Variable;
        auto f    = n.as!Function;
        auto comp = n.as!Composite;

        if(v && v.name==name) {
            if(v.type.isUnknown) ready = false;
            results.add(Callable(v));
        } else if(f && f.name==name) {
            if(f.isImport) {
                auto m = PPL2.getModule(f.moduleName);
                if(m && m.isParsed) {
                    auto fns = m.getFunctions(name);
                    if(fns.length==0) {
                        throw new CompilerError(Err.IMPORT_NOT_FOUND, n,
                        "Import %s not found in module %s".format(name, f.moduleName));
                    }
                    foreach(fn; fns) {
                        results.add(Callable(fn));

                        if(fn.getType.isUnknown) ready = false;

                        functionRequired(fn.moduleName, name);
                    }
                } else {
                    /// Bring the import in and start parsing it
                    functionRequired(f.moduleName, name);
                    ready = false;
                }
            } else {
                if(f.isTemplate || f.getType.isUnknown) ready = false;
                results.add(Callable(f));
                functionRequired(module_.canonicalName, name);
            }
        } else if(comp) {
            foreach(ch; comp.children[]) {
                check(name, ch, results, ready);
            }
        }
    }
    ///
    /// Filter out any overloads that do not have the correct param names
    ///
    /// Assume:
    ///     Assume all function names are the same
    ///     Assume all types are known
    ///     paramNames must match actual param names
    ///     paramNames are unique
    void filter(Call call, Array!Callable overloads) {
        import common : indexOf;

        bool isPossibleImplicitThisCall =
            call.name!="new" &&
            call.isStartOfChain &&
            call.hasAncestor!NamedStruct;

        lp:foreach(callable; overloads[].dup) {

            if(!callable.getType.isFunction) {
                overloads.remove(callable);
                continue;
            }

            Type[] params  = callable.paramTypes();
            Type[] args    = call.argTypes;

            if(isPossibleImplicitThisCall) {
                /// There may be an implied "this." in front of this call
                if(callable.isStructMember) {
                    auto callerStruct = call.getAncestor!NamedStruct;
                    auto funcStruct   = callable.getNode.getAncestor!NamedStruct;
                    if(callerStruct.nid==funcStruct.nid) {
                        /// This is a call within the same struct
                        args = params[0] ~ args;
                    }
                }
            }

            /// Check the number of params
            if(params.length != args.length) {
                overloads.remove(callable);
                continue;
            }

            if(call.paramNames.length > 0) {
                int count = 0;
                string[] names = callable.paramNames();
                foreach(i, name; call.paramNames) {
                    int index = names.indexOf(name);
                    if(index==-1) {
                        overloads.remove(callable);
                        continue lp;
                    }
                    count++;
                    auto arg   = args[i];
                    auto param = params[index];

                    if(!arg.canImplicitlyCastTo(param)) {
                        overloads.remove(callable);
                        continue lp;
                    }
                }

            } else {
                if(!canImplicitlyCastTo(args, params)) {
                    overloads.remove(callable);
                    continue;
                }
            }
        }
        if(overloads.length > 1) {
            selectExactMatch(call, overloads);
        }
    }
    ///
    /// Select 1 match if it matches the args exactly.
    ///
    /// Assume:
    ///     All types are known
    ///     overloads.length > 1
    ///     all overloads match the call implicitly
    ///
    void selectExactMatch(Call call, Array!Callable overloads) {
        import common : indexOf;

        lp:foreach(callable; overloads[]) {
            Type[] params = callable.paramTypes();

            if(call.paramNames.length > 0) {
                string[] names = callable.paramNames();
                foreach(i, name; call.paramNames) {
                    int index = names.indexOf(name);
                    assert(index != -1);

                    auto arg   = call.argTypes[i];
                    auto param = params[index];

                    if(!arg.exactlyMatches(param)) continue lp;
                }
            } else {
                foreach(i, a; call.argTypes) {
                    if(!a.exactlyMatches(params[i])) continue lp;
                }
            }

            /// Exact match found
            foreach(o; overloads[].dup) {
                if(o.id != callable.id) overloads.remove(o);
            }
            assert(overloads.length==1);
        }
    }
    /// Extract one or more function templates
    ///
    /// If the template is in this module:
    ///     - Extract the tokens and add them to the module
    ///
    ///
    /// If the template is in another module:
    ///     - Create one proxy Function within this module using the mangled name
    ///
    ///
    ///
    ///
    ///
    ///
    void extractTemplate(Call call, string mangledName) {
        /// Find the template(s)
        overloads.clear();
        collectOverloadSet(call.name, call, overloads);
        if(overloads.length==0) {
            throw new CompilerError(Err.FUNCTION_NOT_FOUND, call,
                "Function template %s not found".format(call.name));
        }
        foreach(ft; overloads[]) {
            if(ft.isFunction) {
                auto f = ft.func;
                if(f.isTemplate) {
                    /// Function template within this module
                    module_.templates.extract(f, call, mangledName);
                } else if(f.isImport) {
                    assert(false, "implement me");
                }
            } else assert(false, "Handle funcptr template");
        }
    }
}