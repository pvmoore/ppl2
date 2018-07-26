module ppl2.templates.ImplicitTemplates;

import ppl2.internal;

final class ImplicitTemplates {
private:
    Module module_;
    Tokens nav;
    ParamTypeEstimator typeEstimator;
public:
    this(Module module_) {
        this.module_       = module_;
        this.nav           = new Tokens(module_, null);
        this.typeEstimator = new ParamTypeEstimator;
    }
    ///
    ///
    ///
    bool getNonStructTemplate(Call call, Array!Function templateFuncs) {


        return false;
    }
    bool getStructMemberTemplate(NamedStruct ns, Call call, Array!Function templateFuncs) {
        dd("===================================== Get possible struct function templates", call.name, "(", call.argTypes.prettyString,")");

        import common : contains;

        if(call.name.contains("<") || call.numArgs<2) {
            return false;
        }

        Type[] templateTypes;

        foreach(f; templateFuncs) {
            if(f.blueprint.numFuncParams == call.numArgs) {
                if(checkPossibleMatch(ns, f, call, templateTypes)) {
                    dd("   MATCH", "<", templateTypes.prettyString, ">");

                    /// Set the template types on the call
                    call.templateTypes = templateTypes;
                    return true;
                }
            }
        }
        return false;
    }
private:
    ///
    /// Assume num function params are correct
    ///
    bool checkPossibleMatch(NamedStruct ns, Function f, Call call, ref Type[] templateTypes) {
        dd("  Checking template", f.blueprint);

        templateTypes = typeEstimator.getEstimatedParams(ns, call, f);
        dd("  got param estimates:", "<", templateTypes.map!(it=>it.prettyString).join(","), ">");

        Type[] paramTypes = f.blueprint.getFuncParamTypes(module_, call, templateTypes);
        dd("  paramTypes=", paramTypes);

        return canImplicitlyCastTo(call.argTypes, paramTypes);
    }
}