module ppl2.templates.ImplicitTemplates;

import ppl2.internal;
import common : contains;

final class ImplicitTemplates {
private:
    Module module_;
    Tokens nav;
    ParamTypeMatcherRegex typeMatcherRegex;
    IdentifierResolver identifierResolver;
public:
    this(Module module_) {
        this.module_            = module_;
        this.nav                = new Tokens(module_, null);
        this.typeMatcherRegex   = new ParamTypeMatcherRegex(module_);
        this.identifierResolver = new IdentifierResolver(module_);
    }
    bool find(NamedStruct ns, Call call, Array!Function templateFuncs) {
        //dd("================== Get implicit function templates for call", call.name, "(", call.argTypes,")");

        /// Exit if call is already templated or there are no non-this args
        if(call.name.contains("<")) return false;
        if(call.numArgs==0) return false;
        if(call.implicitThisArgAdded && call.numArgs==1) return false;

        /// The call has at least 1 arg that we can use to match to a template param type

        Type[] templateTypes;

        foreach(f; templateFuncs) {
            if(f.blueprint.numFuncParams == call.numArgs) {

                if(typeMatcherRegex.getEstimatedParams(call, f, templateTypes)) {
                    //dd("   MATCH", "<", templateTypes.prettyString, ">");

                    /// Set the template types on the call
                    call.templateTypes = templateTypes;
                    return true;
                }
            }
        }

        /// If we get here without a match and the call is from within a struct
        /// then try adding the implicit this* and check for template matches within the same struct
        if(ns && !call.implicitThisArgAdded) {

            /// Add implicit this* as 1st arg
            auto r = identifierResolver.findFirst("this", call);
            if(!r.found) return false;

            call.addImplicitThisArg(r.var);

            if(find(ns, call, templateFuncs)) {
                return true;
            }

            /// Remove the 1st arg this*
            call.first().detach();
        }
        return false;
    }
}