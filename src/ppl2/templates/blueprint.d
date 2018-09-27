module ppl2.templates.blueprint;

import ppl2.internal;

final class TemplateBlueprint {
    Token[] tokens;
    string[] paramNames;
    Token[][] argTokens;    /// for function templates only
    bool isFunction;
    Tokens nav;

    this() {
        this.nav = new Tokens(null, null);
    }

    int numTemplateParams() {
        return paramNames.length.as!int;
    }
    int numFuncParams() {
        return argTokens.length.as!int;
    }
    int indexOf(string paramName) {
        foreach(int i, n; paramNames) {
            if(n==paramName) return i;
        }
        return -1;
    }
    void setTokens(NamedStruct ns, Token[] tokens) {
        this.tokens = tokens;
        assert(tokens.length>0);

        if(tokens[0].type==TT.LCURLY) {
            isFunction = true;

            /// Add this* as first parameter if this is a struct function template
            if(ns) {
                Token[] this_ = [tok("__this*", PtrType.of(ns, 1)), tok("this")];
                argTokens = this_ ~ argTokens;
            }

            auto nav = new Tokens(null, tokens);
            nav.next;
            int arrow = nav.findInScope(TT.RT_ARROW);
            if(arrow==-1) return;

            nav.setLength(nav.index+arrow);

            int start = nav.index;

            int sq = 0, curly = 0;

            while(nav.hasNext) {
                switch(nav.type) {
                    case TT.LCURLY: curly++; nav.next; break;
                    case TT.RCURLY: curly--; nav.next; break;
                    case TT.LSQBRACKET: sq++; nav.next; break;
                    case TT.RSQBRACKET: sq--; nav.next; break;
                    case TT.COMMA:
                        if(curly==0 && sq==0) {
                            argTokens ~= nav.get(start, nav.index-1);
                            nav.next;
                            start = nav.index;
                        } else {
                            nav.next;
                        }
                        break;
                    default:
                        nav.next;
                        break;
                }
            }
            if(start != nav.index) {
                argTokens ~= nav.get(start, nav.index-1);
            }

            //dd("  argTokens=", argTokens.map!(it=>it.toString).join(", "), "(%s params)".format(argTokens.length));
        }
    }
    Token[] extractStruct(string mangledName, Type[] types) {
        /// struct mangledName =
        Token[] tokens = [
            tok("struct"),
            tok(mangledName),
            tok(TT.EQUALS)
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
        if(isStatic) tokens ~= tok("static");

        tokens ~= [
            tok(mangledName),
            tok(TT.EQUALS)
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
    Type[] getFuncParamTypes(Module module_, Call call, Type[] templateTypes) {
        assert(templateTypes.length==paramNames.length);

        Type[] paramTypes;
        foreach(at; argTokens) {
            auto tokens = at.dup;

            nav.reuse(module_, tokens);

            applyTypes(tokens, templateTypes);

            paramTypes ~= module_.typeParser.parse(nav, call, false);
        }
        return paramTypes;
    }
    override string toString() {
        if(isFunction) {
            return "(%s)".format(argTokens.map!(it=>it.toString).join(", "));
        }
        return super.toString();
    }
private:
    Token tok(string value) {
        auto t  = copyToken(tokens[0]);
        t.type  = TT.IDENTIFIER;
        t.value = value;
        return t;
    }
    Token tok(TT e) {
        auto t  = copyToken(tokens[0]);
        t.type  = e;
        t.value = "";
        return t;
    }
    Token tok(string value, Type ty) {
        auto t         = copyToken(tokens[0]);
        t.type         = TT.IDENTIFIER;
        t.value        = value;
        t.templateType = ty;
        return t;
    }
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