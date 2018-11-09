module ppl2.templates.blueprint;

import ppl2.internal;

final class TemplateBlueprint {
private:
    Module module_;
    Tokens nav;
    ParamTokens paramTokens;
public:
    Token[] tokens;
    string[] paramNames;

    bool isFunction;
    Set!string extracted;

    this(Module module_) {
        this.module_   = module_;
        this.nav       = new Tokens(null, null);
        this.extracted = new Set!string;
    }

    int numTemplateParams() {
        return paramNames.length.as!int;
    }
    int numFuncParams() {
        return paramTokens.numParams;
    }
    ParamTokens getParamTokens() {
        return paramTokens;
    }
    int indexOf(string paramName) {
        foreach(int i, n; paramNames) {
            if(n==paramName) return i;
        }
        return -1;
    }
    void setStructTokens(NamedStruct ns, string[] paramNames, Token[] tokens) {
        assert(tokens.length>0);
        assert(tokens[0].type==TT.LCURLY);
        assert(tokens[$-1].type==TT.RCURLY);

        this.paramNames = paramNames;
        this.tokens     = tokens;
    }
    void setFunctionTokens(NamedStruct ns, string[] paramNames, Token[] tokens) {
        assert(tokens.length>0);
        assert(tokens[0].type==TT.LCURLY);
        assert(tokens[$-1].type==TT.RCURLY);

        this.isFunction  = true;
        this.paramNames  = paramNames;
        this.tokens      = tokens;
        this.paramTokens = new ParamTokens(ns, paramNames, tokens);
    }
    Token[] extractStruct(string mangledName, Type[] types) {
        /// struct mangledName
        Token[] tokens = [
            this.tokens[0].copy("struct"),
            this.tokens[0].copy(mangledName)
        ] ~ this.tokens.dup;

        foreach(ref t; tokens) {
            if(t.type==TT.IDENTIFIER) {
                int i = indexOf(t.value);
                if(i!=-1) {
                    t.templateType = types[i];
                }
            }
        }
        return tokens;
    }
    Token[] extractFunction(string mangledName, Type[] types, bool isStatic) {
        /// [static] mangledName = {

        Token[] tokens;
        if(isStatic) tokens ~= this.tokens[0].copy("static");

        tokens ~= [
            this.tokens[0].copy(mangledName)
        ] ~ this.tokens.dup;

        foreach(ref t; tokens) {
            if(t.type==TT.IDENTIFIER) {
                int i = indexOf(t.value);
                if(i!=-1) {
                    t.templateType = types[i];
                }
            }
        }
        return tokens;
    }
    bool isProxy(Token tok) {
        import common : contains;
        return tok.type==TT.IDENTIFIER && paramNames.contains(tok.value);
    }
    /*
    /// Return a list of proxies used in param tokens in order of usage.
    /// eg. for these tokens:  [A a, B b, A c] c
    /// The proxy list is      ["A","B","A"]
    string[] getProxyListForParam(int paramIndex) {
        assert(paramIndex>=0 && paramIndex<argTokens.length);

        string[] list; list.reserve(8);
        foreach(t; argTokens[paramIndex]) {
            if(isProxy(t)) list ~= t.value;
        }
        return list;
    }
    /// eg. turn this array of tokens:
    ///     [A a, B b, A c] c
    /// into this:
    ///     "\[(.*),(.*),(.*)\]" with proxyList ["A","B","A"]
    string getRegexStringForParam(int paramIndex) {
        assert(node.isA!Function);
        assert(paramIndex>=0 && paramIndex<argTokens.length);

        if(cachedRegex[paramIndex] !is null) {
            dd("cached");
            return cachedRegex[paramIndex];
        }
        dd("uncached");

        static class ProxyType : Type {
            int getEnum() const { return -1; }
            bool isKnown() { return true; }
            bool exactlyMatches(Type other) { return false; }
            bool canImplicitlyCastTo(Type other) { return false; }
            LLVMTypeRef getLLVMType() { return null; }
            override string toString() { return "__P__"; }
        }
        Type proxy = new ProxyType;

        auto tempTokens = argTokens[paramIndex].dup;

        foreach(ref t; tempTokens) {
            if(isProxy(t)) t.templateType = proxy;
        }

        nav.reuse(module_, tempTokens);

        Type type = module_.typeParser.parseForTemplate(nav, node);

        if(type is null || type.isUnknown) {
            cachedRegex[paramIndex] = "";
        } else {
            import std.array : replace;
            cachedRegex[paramIndex] = escapeRegex("%s".format(type)).replace("__P__", "(.*)");
        }

        return cachedRegex[paramIndex];
    }*/
    Type[] getFuncParamTypes(Module module_, Call call, Type[] templateTypes) {
        assert(templateTypes.length==paramNames.length);

        Type[] paramTypes;
        foreach(at; paramTokens.getTokensForAllParams()) {
            auto tokens = at.dup;

            nav.reuse(module_, tokens);

            applyTypes(tokens, templateTypes);

            paramTypes ~= module_.typeParser.parse(nav, call, false);
        }
        return paramTypes;
    }
    override string toString() {
        if(isFunction) {
            return "(%s)".format(paramTokens.getTokensForAllParams().map!(it=>"%s".format(it)).join(", "));
        }
        return super.toString();
    }
private:
    void applyTypes(Token[] tokens, Type[] types) {
        foreach(ref tok; tokens) {
            if(tok.type==TT.IDENTIFIER) {
                long index = indexOf(tok.value);
                if(index!=-1) {
                    tok.templateType = types[index];
                }
            }
        }
    }
}