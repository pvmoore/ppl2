module ppl2.templates.templates;

import ppl2.internal;

final class Templates {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    void clearState() {

    }
    ///
    /// Extract a struct template
    ///
    void extract(NamedStruct ns, ASTNode requestingNode, string mangledName, Type[] templateTypes) {
        assert(ns.moduleName==module_.canonicalName);

        if(templateTypes.length != ns.blueprint.numTemplateParams) {
            module_.addError(requestingNode, "Expecting %s template parameters".format(ns.blueprint.numTemplateParams), true);
            return;
        }

        if(ns.blueprint.extracted.contains(mangledName)) return;
        ns.blueprint.extracted.add(mangledName);

        auto tokens = ns.blueprint.extractStruct(mangledName, templateTypes);

        module_.parser.appendTokensFromTemplate(ns, tokens);

        module_.buildState.aliasOrStructRequired(module_.canonicalName, mangledName);

        //if(module_.canonicalName=="test_statics") {
        //    dd("Extracted struct template", ns.name, mangledName, module_.canonicalName);
        //    dd("~~~", tokens.toString);
        //}
    }
    ///
    /// Extract several function templates
    ///
    void extract(Function[] funcs, Call call, string mangledName) {
        assert(funcs.all!(f=>f.moduleName==module_.canonicalName));

        //dd("    extracting", call.name, mangledName, funcs);

        foreach(f; funcs) {

            if(call.templateTypes.length != f.blueprint.numTemplateParams) {
                module_.addError(call, "Expecting %s template parameters".format(f.blueprint.numTemplateParams), true);
                return;
            }

            NamedStruct ns;
            string key = mangledName;

            if(f.isStructMember || f.isStatic) {
                ns = f.getStruct.parent.as!NamedStruct;
                assert(ns);
                key = ns.getUniqueName ~ "." ~ mangledName;
            }

            //dd("    key=", key);

            if(f.blueprint.extracted.contains(key)) return;
            f.blueprint.extracted.add(key);

            //dd("    Extracting function template", f.name, ",", mangledName, ns ? "(struct "~ns.name~")" : "", module_.canonicalName);

            auto tokens = f.blueprint.extractFunction(mangledName, call.templateTypes, f.isStatic);
            //dd("  tokens=", tokens.toString);

            module_.parser.appendTokensFromTemplate(f, tokens);

            module_.buildState.functionRequired(module_.canonicalName, mangledName);
        }
    }
}
