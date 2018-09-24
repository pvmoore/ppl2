module ppl2.templates.templates;

import ppl2.internal;

final class Templates {
private:
    Module module_;
    Set!string extractedStructs;
    Set!string extractedFunctions;
    Tokens nav;
public:
    this(Module module_) {
        this.module_            = module_;
        this.extractedStructs   = new Set!string;
        this.extractedFunctions = new Set!string;
        this.nav                = new Tokens(module_, null);
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

        //dd("Extracting struct template", ns.name, mangledName, module_.canonicalName);

        auto tokens = ns.blueprint.extractStruct(mangledName, templateTypes);

        module_.parser.appendTokens(ns, tokens);

        aliasOrStructRequired(module_.canonicalName, mangledName);
    }
    ///
    /// Extract several function templates
    ///
    void extract(Function[] funcs, Call call, string mangledName) {
        assert(funcs.all!(f=>f.moduleName==module_.canonicalName));

        auto keys = new Set!string;

        foreach(f; funcs) {

            if(call.templateTypes.length != f.blueprint.numTemplateParams) {
                throw new CompilerError(call,
                    "Expecting %s template parameters".format(f.blueprint.numTemplateParams));
            }

            NamedStruct ns;
            string key = mangledName;

            if(f.isStructMember) {
                ns = f.getStruct.parent.as!NamedStruct;
                assert(ns);
                key = ns.getUniqueName ~ "." ~ mangledName;
            }

            if(extractedFunctions.contains(key)) return;

            //extractedFunctions.add(key);
            keys.add(key);

            //dd("Extracting function template", f.name, mangledName, ns ? "(struct "~ns.name~")" : "", module_.canonicalName);

            auto tokens = f.blueprint.extractFunction(mangledName, call.templateTypes);
            //dd("  tokens=", tokens.toString);

            module_.parser.appendTokens(f, tokens);

            functionRequired(module_.canonicalName, mangledName);
        }

        /// Ensure these templates are not extract again with the same params
        foreach(k; keys.values) {
            extractedFunctions.add(k);
        }
    }
}
