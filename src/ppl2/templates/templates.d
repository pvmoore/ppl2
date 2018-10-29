module ppl2.templates.templates;

import ppl2.internal;

final class Templates {
private:
    Module module_;
    Set!string extractedStructs;
    Set!string extractedFunctions;
public:
    this(Module module_) {
        this.module_            = module_;
        this.extractedStructs   = new Set!string;
        this.extractedFunctions = new Set!string;
    }
    void clearState() {
        extractedStructs.clear();
        extractedFunctions.clear();
    }
    ///
    /// Extract a struct template
    ///
    void extract(NamedStruct ns, ASTNode requestingNode, string mangledName, Type[] templateTypes) {
        assert(ns.moduleName==module_.canonicalName);

        if(extractedStructs.contains(mangledName)) return;
        extractedStructs.add(mangledName);

        if(templateTypes.length != ns.blueprint.numTemplateParams) {
            throw new CompilerError(requestingNode,
                "Expecting %s template parameters".format(ns.blueprint.numTemplateParams));
        }

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

        auto keys = new Set!string;

        foreach(f; funcs) {

            if(call.templateTypes.length != f.blueprint.numTemplateParams) {
                throw new CompilerError(call,
                    "Expecting %s template parameters".format(f.blueprint.numTemplateParams));
            }

            NamedStruct ns;
            string key = mangledName;

            if(f.isStructMember || f.isStatic) {
                ns = f.getStruct.parent.as!NamedStruct;
                assert(ns);
                key = ns.getUniqueName ~ "." ~ mangledName;
            }

            //dd("    key=", key);

            if(extractedFunctions.contains(key)) return;

            //extractedFunctions.add(key);
            keys.add(key);

            //dd("    Extracting function template", f.name, ",", mangledName, ns ? "(struct "~ns.name~")" : "", module_.canonicalName);

            auto tokens = f.blueprint.extractFunction(mangledName, call.templateTypes, f.isStatic);
            //dd("  tokens=", tokens.toString);

            module_.parser.appendTokensFromTemplate(f, tokens);

            module_.buildState.functionRequired(module_.canonicalName, mangledName);
        }

        /// Ensure these templates are not extract again with the same params
        foreach(k; keys.values) {
            extractedFunctions.add(k);
        }
    }
}
