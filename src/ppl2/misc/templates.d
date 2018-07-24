module ppl2.misc.templates;

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

        if(templateTypes.length != ns.templateParamNames.length) {
            throw new CompilerError(Err.TEMPLATE_INCORRECT_NUM_PARAMS, requestingNode,
                "Expecting %s template parameters".format(ns.templateParamNames.length));
        }

        dd("Extracting struct template", ns.name, mangledName, module_.canonicalName);

        /// struct mangledName =
        Token[] tokens = [
            stringToken(ns.tokens, "struct"),
            stringToken(ns.tokens, mangledName),
            ttToken(ns.tokens, TT.EQUALS)
        ] ~ ns.tokens.dup;

        foreach(ref tok; tokens) {
            if(tok.type==TT.IDENTIFIER) {
                int i = paramIndex(ns.templateParamNames, tok.value);
                if(i!=-1) {
                    tok.templateType = templateTypes[i];
                }
            }
        }

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

        if(call.templateTypes.length != f.templateParamNames.length) {
            throw new CompilerError(Err.TEMPLATE_INCORRECT_NUM_PARAMS, call,
                "Expecting %s template parameters".format(f.templateParamNames.length));
        }

        dd("Extracting function template", f.name, mangledName, module_.canonicalName);

        /// mangledName = {
        Token[] tokens = [
            stringToken(f.tokens, mangledName),
            ttToken(f.tokens, TT.EQUALS)
        ] ~ f.tokens.dup;

        dd("  tokens=", tokens.toString);

        foreach(ref tok; tokens) {
            if(tok.type==TT.IDENTIFIER) {
                int i = paramIndex(f.templateParamNames, tok.value);
                if(i!=-1) {
                    tok.templateType = call.templateTypes[i];
                }
            }
        }

        module_.parser.appendTokens(f, tokens);

        functionRequired(module_.canonicalName, mangledName);
    }
private:
    Token stringToken(Token[] tokens, string value) {
        auto t  = copyToken(tokens[0]);
        t.type  = TT.IDENTIFIER;
        t.value = value;
        return t;
    }
    Token ttToken(Token[] tokens, TT e) {
        auto t  = copyToken(tokens[0]);
        t.type  = e;
        t.value = "";
        return t;
    }
    Token typeToken(Token[] tokens, Type ty) {
        auto t         = copyToken(tokens[0]);
        t.type         = TT.IDENTIFIER;
        t.value        = "type";
        t.templateType = ty;
        return t;
    }
    int paramIndex(string[] templateParamNames, string param) {
        foreach(int i, n; templateParamNames) {
            if(n==param) return i;
        }
        return -1;
    }
}
