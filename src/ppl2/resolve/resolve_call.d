module ppl2.resolve.resolve_call;

import ppl2.internal;
import common : contains;
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
    bool isTemplateBlueprint() { return func ? func.isTemplateBlueprint : false; }

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
    Array!Function funcTemplates;
    OverloadCollector collector;
    ImplicitTemplates implicitTemplates;
public:
    this(Module module_) {
        this.module_           = module_;
        this.overloads         = new Array!Callable;
        this.funcTemplates     = new Array!Function;
        this.collector         = new OverloadCollector;
        this.implicitTemplates = new ImplicitTemplates(module_);
    }

    /// Assume:
    ///     call.argTypes may not yet be known
    ///
    Callable standardFind(Call call) {

        NamedStruct ns = call.getAncestor!NamedStruct;

        if(call.isTemplated && !call.name.contains("<")) {
            /// We can't do anything until the template types are known
            if(!call.templateTypes.areKnown) {
                return CALLABLE_NOT_READY;
            }
            string mangledName = call.name ~ "<" ~ mangle(call.templateTypes) ~ ">";

            /// Possible implicit this.call<...>(...)
            if(ns) {
                extractTemplate(ns, call, mangledName);
            }

            if(extractTemplate(call, mangledName)) {
                call.name = mangledName;
            }
            return CALLABLE_NOT_READY;
        }

        /// Come back when all root level Composites have been removed
        if(ns && ns.type.containsComposites) {
            return CALLABLE_NOT_READY;
        }

        //dd("looking for", call.name);

        /// From this point on we don't include any template blueprints

        if(collector.collect(call.name, call, overloads)) {

            if(overloads.length==1 && !overloads[0].isTemplateBlueprint) {
                /// Return this result as it's the only one and check it later
                /// to make sure the types match
                return overloads[0];
            }

            /// From this point onwards we need the resolved types
            if(!call.argTypes.areKnown) return CALLABLE_NOT_READY;

            filterOverloads(call);

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

        /// Come back when all root level Composites have been removed
        if(struct_.containsComposites) {
            return CALLABLE_NOT_READY;
        }

        if(call.isTemplated && !call.name.contains("<")) {
            string mangledName = call.name ~ "<" ~ mangle(call.templateTypes) ~ ">";

            extractTemplate(ns, call, mangledName);
            call.name = mangledName;
            return CALLABLE_NOT_READY;
        }

        //dd("structFind looking for", call.name);

        auto fns      = struct_.getMemberFunctions(call.name);
        auto var      = struct_.getMemberVariable(call.name);
        auto thisType = PtrType.of(ns, 1);

        /// Filter
        overloads.clear();
        foreach(f; fns) overloads.add(Callable(f));
        if(var && var.isFunctionPtr) overloads.add(Callable(var));

        filterOverloads(call);

        if(overloads.length==0) {

            if(funcTemplates.length>0) {
                /// There is a template with the same name. Try that
                if(implicitTemplates.getStructMemberTemplate(ns, call, funcTemplates)) {
                    /// If we get here then we found a match.
                    /// call.templateTypes have been set
                    return CALLABLE_NOT_READY;
                }
            }

            string msg;
            if(call.paramNames.length>0) {
                auto buf = new StringBuffer;
                foreach(i, n; call.paramNames) {
                    if(i>0) buf.add(", ");
                    buf.add(n).add("=").add(call.argTypes[i].prettyString);
                }
                msg = "Struct %s does not have function %s(%s)"
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
    /// Filter out any overloads that do not have the correct param names
    /// Add any filtered out function templates to funcTemplates
    ///
    /// Assume:
    ///     Assume all function names are the same
    ///     Assume all types are known
    ///     paramNames must match actual param names
    ///     paramNames are unique
    void filterOverloads(Call call) {
        import common : indexOf;

        funcTemplates.clear();

        bool isPossibleImplicitThisCall =
            call.name!="new" &&
            call.isStartOfChain &&
            call.hasAncestor!NamedStruct;

        lp:foreach(callable; overloads[].dup) {

            if(callable.isTemplateBlueprint) {
                overloads.remove(callable);
                funcTemplates.add(callable.func);
                continue;
            }
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
                /// name=value arg list
                string[] names = callable.paramNames();
                foreach(i, name; call.paramNames) {
                    int index = names.indexOf(name);
                    assert(index != -1);

                    auto arg   = call.argTypes[i];
                    auto param = params[index];

                    if(!arg.exactlyMatches(param)) continue lp;
                }
            } else {
                /// standard arg list
                foreach(i, a; call.argTypes) {
                    if(!a.exactlyMatches(params[i])) continue lp;
                }
            }

            //dd("  exact match", callable.id, overloads[]);

            /// Exact match found
            foreach(o; overloads[].dup) {
                if(o.id != callable.id) overloads.remove(o);
            }
            assert(overloads.length==1);
        }
    }
    ///
    /// Extract one or more function templates:
    ///
    /// If the template is in this module:
    ///     - Extract the tokens and add them to the module
    ///
    /// If the template is in another module:
    ///     - Create one proxy Function within this module using the mangled name
    ///     - Extract the tokens in the other module
    ///
    bool extractTemplate(Call call, string mangledName) {
        assert(call.isTemplated);

        /// Find the template(s)
        if(!collector.collect(call.name, call, overloads)) {
            return false;
        }

        if(overloads.length==0) {
            //throw new CompilerError(Err.FUNCTION_NOT_FOUND, call,
            //    "Function template %s not found".format(call.name));
            return true;
        }

        foreach(ft; overloads[]) {
            if(ft.isFunction) {
                auto f = ft.func;
                assert(!f.isImport);

                if(f.isTemplateBlueprint && f.blueprint.numTemplateParams==call.templateTypes.length) {
                    /// Extract the tokens
                    auto m = PPL2.getModule(f.moduleName);
                    m.templates.extract(f, call, mangledName);

                    if(m.nid!=module_.nid) {
                        /// Create the proxy
                        auto proxy       = makeNode!Function;
                        proxy.name       = mangledName;
                        proxy.moduleName = m.canonicalName;
                        proxy.isImport   = true;
                        module_.addToEnd(proxy);
                    }
                }
            } else assert(false, "funcptrs cannot be templated");
        }
        return true;
    }
    ///
    /// Extract one or more struct function templates
    ///
    void extractTemplate(NamedStruct ns, Call call, string mangledName) {
        assert(call.isTemplated);

        AnonStruct struct_ = ns.type;
        auto fns = struct_.getMemberFunctions(call.name);

        foreach(f; fns) {
            if(!f.isTemplateBlueprint) continue;
            if(f.blueprint.numTemplateParams!=call.templateTypes.length) continue;
            if(f.blueprint.numFuncParams!=call.numArgs) continue;

            /// Extract the tokens
            auto m = PPL2.getModule(f.moduleName);
            m.templates.extract(f, call, mangledName);
        }
    }
}
