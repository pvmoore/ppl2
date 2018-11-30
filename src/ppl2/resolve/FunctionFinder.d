module ppl2.resolve.FunctionFinder;

import ppl2.internal;
import common : contains;

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
    bool resultReady()         { return getNode() !is null; }
    bool isVariable()          { return var !is null; }
    bool isFunction()          { return func !is null; }
    bool isStatic()            { return var ? var.isStatic : func.isStatic; }
    bool isStructMember()      { return func ? func.isStructMember : var.isStructMember; }
    bool isTemplateBlueprint() { return func ? func.isTemplateBlueprint : false; }
    bool isPrivate()           { return (func ? func.access : var.access).isPrivate; }

    string getName()           { return func ? func.name : var.name; }
    Type getType()             { return func ? func.getType : var.type; }
    ASTNode getNode()          { return func ? func : var; }
    int numParams()            { return getType.getFunctionType.numParams; }
    string[] paramNames()      { return getType.getFunctionType.paramNames; }
    Type[] paramTypes()        { return getType.getFunctionType.paramTypes; }
    Module getModule()         { return func ? func.getModule : var.getModule; }

    size_t toHash() const @safe pure nothrow {
        assert(id!=0);
        return id;
    }
    /// Every node is unique
    bool opEquals(ref const Callable o) const @safe  pure nothrow {
        assert(id!=0 && o.id!=0);
        return o.id==id;
    }
    string toString() {
        if(!resultReady) return "Not ready";
        string t = isTemplateBlueprint() ? " TEMPLATE":"";
        if(!getType.getFunctionType) {
            return "%s%s %s(type=%s)".format(func?"FUNC":"VAR", t, getName, getType);
        }
        return "%s%s %s(%s)".format(func?"FUNC":"VAR", t, getName, paramTypes);
    }
}
//============================================================================================

final class FunctionFinder {
private:
    Module module_;
    OverloadCollector collector;
    ImplicitTemplates implicitTemplates;
    Array!Callable overloads;
    Array!Function funcTemplates;
public:
    this(Module module_) {
        this.module_           = module_;
        this.collector         = new OverloadCollector(module_);
        this.implicitTemplates = new ImplicitTemplates(module_);
        this.overloads         = new Array!Callable;
        this.funcTemplates     = new Array!Function;
    }
    /// Assume:
    ///     call.argTypes may not yet be known
    ///
    Callable standardFind(Call call, ModuleAlias modAlias=null) {
        //dd("resolveCall", call.name);

        /// Come back when all root level Composites have been removed
        //if(module_.containsComposites) {
        //    return CALLABLE_NOT_READY;
        //}

        Struct ns = call.isStartOfChain() ?
        call.getAncestor!Struct : null;

        if(call.isTemplated && !call.name.contains("<")) {
            /// We can't do anything until the template types are known
            if(!call.templateTypes.areKnown) {
                return CALLABLE_NOT_READY;
            }
            string mangledName = call.name ~ "<" ~ module_.buildState.mangler.mangle(call.templateTypes) ~ ">";

            /// Possible implicit this.call<...>(...)
            if(ns) {
                extractTemplates(ns, call, mangledName, false);
            }

            if(extractTemplates(call, modAlias, mangledName)) {
                call.name = mangledName;
            }
            return CALLABLE_NOT_READY;
        }

        /// Come back when all root level Composites have been removed
        if(ns && ns.containsComposites) {
            return CALLABLE_NOT_READY;
        }

        chat("looking for %s", call.name);

        if(collector.collect(call, modAlias, overloads)) {

            int numRemoved = removeInvisible();

            chat("overloads = %s (%s invisible)", overloads, numRemoved);

            if(overloads.length==1 && overloads[0].isTemplateBlueprint) {
                /// If we get here then we have a possible template match but
                /// not enough information to extract it
            }

            if(overloads.length==1 && !overloads[0].isTemplateBlueprint) {

                auto r = overloads[0];

                //if(call.numArgs==r.numParams &&
                //   call.argTypes.areKnown &&
                //  !call.argTypes.canImplicitlyCastTo(r.paramTypes))
                //{
                //    /// Ok we have enough info to know this won't work
                //
                //
                //}

                /// Return this result as it's the only one and check it later
                /// to make sure the types match

                return r;
            }

            /// From this point onwards we need the resolved types
            if(!call.argTypes.areKnown) return CALLABLE_NOT_READY;

            filterOverloads(call);

            chat("after filtering, overloads = %s", overloads);

            if(overloads.length==0) {

                if(funcTemplates.length > 0) {
                    /// There is a template with the same name. Try that
                    if(implicitTemplates.find(ns, call, funcTemplates)) {
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
                        buf.add(n).add("=").add("%s".format(call.argTypes[i]));
                    }
                    msg = "Function %s(%s) not found".format(call.name, buf.toString);
                } else {
                    msg = "Function %s(%s) not found".format(call.name, call.argTypes.toString);
                }
                chat("%s", msg);
                module_.addError(call, msg, true);
                return CALLABLE_NOT_READY;
            }
            if(overloads.length > 1) {
                module_.buildState.addError(new AmbiguousCall(module_, call, overloads.values), true);
                return CALLABLE_NOT_READY;
            }

            assert(overloads.length==1);

            /// Add the function to the resolution set
            if(overloads[0].isFunction) {
                module_.buildState.functionRequired(overloads[0].func.getModule.canonicalName, overloads[0].getName);
            }

            return overloads[0];
        }
        return CALLABLE_NOT_READY;
    }
    /// Assume:
    ///     Struct is known
    ///     call.argTypes may not yet be known
    ///
    Callable structFind(Call call, Struct ns, bool staticOnly) {
        chat("structFind %s", call.name);

        assert(ns);

        /// Come back when all root level Composites have been removed
        if(ns.containsComposites) {
            return CALLABLE_NOT_READY;
        }

        if(call.isTemplated && !call.name.contains("<")) {
            chat("%s is templated", call.name);
            string mangledName = call.name ~ "<" ~ module_.buildState.mangler.mangle(call.templateTypes) ~ ">";

            extractTemplates(ns, call, mangledName, staticOnly);
            call.name = mangledName;
            return CALLABLE_NOT_READY;
        }

        chat("structFind looking for %s, staticOnly=%s", call.name, staticOnly);

        Function[] fns;
        Variable[] vars;

        if(staticOnly) {
            fns  ~= ns.getStaticFunctions(call.name);
            vars ~= ns.getStaticVariable(call.name);

            chat("    adding static funcs %s", fns);
            //chat("    adding static var %s", var);

            /// Ensure these functions are resolved
            //foreach(f; fns) {
            //    dd("    requesting function", f.name);
            //    functionRequired(f.getModule.canonicalName, f.name);
            //}

        } else {
            fns  ~= ns.getMemberFunctions(call.name);
            vars ~= ns.getMemberVariable(call.name);
        }

        /// Filter
        overloads.clear();
        foreach(f; fns) overloads.add(Callable(f));
        foreach(v; vars) {
            if(v && v.isFunctionPtr) overloads.add(Callable(v));
        }

        chat("   overloads: %s", overloads);

        int numRemoved = removeInvisible();

        chat("   numRemoved: %s", numRemoved);

        /// From this point onwards we need the resolved types
        if(!call.argTypes.areKnown) {

            if(overloads.length>0) {
                return findImplicitMatchWithUnknownArgs(call);
            }

            return CALLABLE_NOT_READY;
        }

        /// Try to filter the results down to one match
        filterOverloads(call);

        chat("    after filter: %s", overloads);

        if(overloads.length==0) {

            if(funcTemplates.length>0) {
                /// There is a template with the same name. Try that
                if(implicitTemplates.find(ns, call, funcTemplates)) {
                    /// If we get here then we found an implicit match.
                    /// call.templateTypes have been set
                    return CALLABLE_NOT_READY;
                }
            }

            /// Function not found

            string argsStr;
            if(call.paramNames.length>0) {
                auto buf = new StringBuffer;
                foreach(i, n; call.paramNames) {
                    if(i>0) buf.add(", ");
                    buf.add(n).add("=").add("%s".format(call.argTypes[i]));
                }
                argsStr = buf.toString;
            } else {
                argsStr = call.argTypes.toString();
            }

            string msg;
            string desc;

            if(staticOnly) {
                desc = "static";
            } else {
                desc = "member";
            }

            if(numRemoved>0) {
                msg ~= "Struct %s %s function %s(%s) is not visible";
            } else {
                msg ~= "Struct %s does not have %s function %s(%s)";
            }
            msg = msg.format(ns.name, desc, call.name, argsStr);

            module_.addError(call, msg, true);

            return CALLABLE_NOT_READY;

        } else if(overloads.length > 1) {
            module_.buildState.addError(new AmbiguousCall(module_, call, overloads.values), true);
            return CALLABLE_NOT_READY;
        }

        //chat("    returning", overloads[0], overloads[0].resultReady);

        assert(overloads.length==1);

        /// Add the static function to the resolution set
        if(overloads[0].isStatic && overloads[0].isFunction) {
            module_.buildState.functionRequired(overloads[0].func.getModule.canonicalName, overloads[0].getName);
        }

        return overloads[0];
    }
private:
    ///
    /// Filter out inaccessible functions
    ///
    int removeInvisible() {
        int thisNID = module_.nid;

        int count = 0;
        foreach(callable; overloads[].dup) {
            if(callable.getModule.nid != thisNID) {
                if(callable.isPrivate) {
                    overloads.remove(callable);
                    count++;
                }
            }
        }
        return count;
    }
    ///
    /// Filter out any overloads that do not have the correct num args, param names etc.
    /// Add any filtered out function templates to funcTemplates
    ///
    /// Assume:
    ///     All function names are the same
    ///     Arg types are known
    ///     paramNames must match actual param names
    ///     paramNames are unique
    void filterOverloads(Call call) {
        import common : indexOf;

        funcTemplates.clear();

        bool isPossibleImplicitThisCall =
        call.name!="new" &&
        !call.implicitThisArgAdded &&
        call.isStartOfChain &&
        call.hasAncestor!Struct;

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
                    auto callerStruct = call.getAncestor!Struct;
                    auto funcStruct   = callable.getNode.getAncestor!Struct;
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
                /// param=expr arg list
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
                /// standard arg list
                if(!canImplicitlyCastTo(args, params)) {
                    overloads.remove(callable);
                    continue;
                }
            }
        }
        /// Only try to select an exact match if we have checked
        /// the arg types and failed to find a distinct match
        if(overloads.length > 1 && call.numArgs()>0) {
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
        assert(overloads.length>0);
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
    bool extractTemplates(Call call, ModuleAlias modAlias, string mangledName) {
        assert(call.isTemplated);

        /// Find the template(s)
        if(!collector.collect(call, modAlias, overloads)) {
            return false;
        }

        if(overloads.length==0) {
            //throw new CompilerError(call,
            //    "Function template %s not found".format(call.name));
            return true;
        }

        Function[][string] toExtract;

        foreach(ft; overloads[]) {
            if(ft.isFunction) {
                auto f = ft.func;
                assert(!f.isImport);

                if(!f.isTemplateBlueprint) continue;
                if(f.blueprint.numTemplateParams!=call.templateTypes.length) continue;

                /// Extract this one
                toExtract[f.moduleName] ~= f;
            }
        }

        foreach(k,v; toExtract) {
            auto m = module_.buildState.getOrCreateModule(k);
            m.templates.extract(v, call, mangledName);

            if(m.nid!=module_.nid) {
                /// Create the proxy
                auto proxy       = makeNode!Function;
                proxy.name       = mangledName;
                proxy.moduleName = m.canonicalName;
                proxy.isImport   = true;

                if(modAlias) {
                    modAlias.imp.add(proxy);
                } else {
                    module_.add(proxy);
                }
            }
        }

        return true;
    }
    ///
    /// Extract one or more struct function templates
    ///
    void extractTemplates(Struct ns, Call call, string mangledName, bool staticOnly)
    {
        assert(call.isTemplated);

        chat("    extracting templates %s -> %s num template params=%s",
        call.name, mangledName, call.templateTypes.length);

        Function[] fns;

        if(staticOnly) {
            fns ~= ns.getStaticFunctions(call.name);
            //mangledName = "%s::%s".format(ns.getUniqueName, mangledName);
        } else {
            fns ~= ns.getMemberFunctions(call.name);
        }

        Function[][string] toExtract;

        foreach(f; fns) {
            if(!f.isTemplateBlueprint) continue;
            if(f.blueprint.numTemplateParams!=call.templateTypes.length) continue;

            /// Extract this one
            toExtract[f.moduleName] ~= f;
        }

        chat("    toExtract = %s", toExtract);

        foreach(k,v; toExtract) {
            auto m = module_.buildState.getOrCreateModule(k);
            m.templates.extract(v, call, mangledName);
        }
    }
    ///
    /// Some of the call args are unknown but we have some name matches.
    /// If we can resolve any function ptr call args then we might
    /// make some progress.
    ///
    /// eg. call args = (int, {UNKNOWN->void})
    /// nameMatches   = (int, {void->void})
    ///                 (int, {int->void})      // <-- match
    ///
    Callable findImplicitMatchWithUnknownArgs(Call call) {
        //if(call.name.indexOf("each")!=-1) dd("findImplicitMatchWithUnknownArgs", call);

        bool checkFuncPtr(FunctionType param, FunctionType arg) {
            bool numArgsMatch() {
                return param.numParams == arg.numParams;
            }
            bool returnTypesSameOrUnknown() {
                return param.returnType.isUnknown ||
                arg.returnType.isUnknown ||
                param.returnType.exactlyMatches(arg.returnType);
            }
            return numArgsMatch() && returnTypesSameOrUnknown();
        }

        foreach(callable; overloads[]) {
            Type[] argTypes   = call.argTypes;
            Type[] paramTypes = callable.paramTypes;

            bool possibleMatch = !callable.isTemplateBlueprint &&
            call.numArgs == callable.numParams;
            for(auto i=0; possibleMatch && i<call.numArgs; i++) {
                auto arg   = argTypes[i];
                auto param = paramTypes[i];

                if(arg.isUnknown) {
                    if(arg.isFunction && param.isFunction) {
                        /// This is an unresolved function ptr argument.
                        /// Filter out where number of args is different.
                        /// If return type is known, filter out if they are different
                        possibleMatch = checkFuncPtr(param.getFunctionType, arg.getFunctionType);
                    } else {
                        /// We have an unknown that we can't handle
                        return CALLABLE_NOT_READY;
                    }
                } else {
                    possibleMatch = arg.canImplicitlyCastTo(param);
                }
            }
            if(possibleMatch) {
                //dd("\tPossible match:", callable);
            } else {
                //dd("\tNot a match   :", callable);
                overloads.remove(callable);
            }
        }
        if(overloads.length==1) {
            //dd("\tWe have a winner", overloads[0]);
            return overloads[0];
        }

        return CALLABLE_NOT_READY;
    }
    void chat(A...)(lazy string fmt, lazy A args) {
        //if(module_.canonicalName=="test") {
        //    dd(format(fmt, args));
        //}
    }
}