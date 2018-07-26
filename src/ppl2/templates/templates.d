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
    void extract(NamedStruct ns, ASTNode requestingNode, string mangledName, Type[] templateTypes) {
        assert(ns.moduleName==module_.canonicalName);

        if(extractedStructs.contains(mangledName)) return;
        extractedStructs.add(mangledName);

        if(templateTypes.length != ns.blueprint.numTemplateParams) {
            throw new CompilerError(Err.TEMPLATE_INCORRECT_NUM_PARAMS, requestingNode,
                "Expecting %s template parameters".format(ns.blueprint.numTemplateParams));
        }

        dd("Extracting struct template", ns.name, mangledName, module_.canonicalName);

        auto tokens = ns.blueprint.extractStruct(mangledName, templateTypes);

        /// struct mangledName =
        //Token[] tokens = [
        //    ns.blueprint.tok("struct"),
        //    ns.blueprint.tok(mangledName),
        //    ns.blueprint.tok(TT.EQUALS)
        //] ~ ns.blueprint.tokens.dup;
        //
        //foreach(ref tok; tokens) {
        //    if(tok.type==TT.IDENTIFIER) {
        //        int i = ns.blueprint.indexOf(tok.value);
        //        if(i!=-1) {
        //            tok.templateType = templateTypes[i];
        //        }
        //    }
        //}

        module_.parser.appendTokens(ns, tokens);

        defineRequired(module_.canonicalName, mangledName);
    }

    void extract(Function f, Call call, string mangledName) {
        assert(f.moduleName==module_.canonicalName);

        NamedStruct ns;
        string key = mangledName;

        if(f.isStructMember) {
            ns = f.getStruct.parent.as!NamedStruct;
            assert(ns);
            key = ns.getUniqueName ~ "." ~ mangledName;
        }

        if(extractedFunctions.contains(key)) return;
        extractedFunctions.add(key);

        if(call.templateTypes.length != f.blueprint.numTemplateParams) {
            throw new CompilerError(Err.TEMPLATE_INCORRECT_NUM_PARAMS, call,
                "Expecting %s template parameters".format(f.blueprint.numTemplateParams));
        }

        dd("Extracting function template", f.name, mangledName, ns ? "(struct "~ns.name~")" : "", module_.canonicalName);

        auto tokens = f.blueprint.extractFunction(mangledName, call.templateTypes);
        dd("  tokens=", tokens.toString);

        module_.parser.appendTokens(f, tokens);

        functionRequired(module_.canonicalName, mangledName);
    }
}
