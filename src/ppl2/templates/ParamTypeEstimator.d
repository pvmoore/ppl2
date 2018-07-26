module ppl2.templates.ParamTypeEstimator;

import ppl2.internal;

const VERBOSE = true;

private void chat(A...)(lazy string fmt, lazy A args) {
    if(VERBOSE)
        dd(format(fmt, args));
}

final class ParamTypeEstimator {
private:
    NamedStruct ns;
    Call call;
    Function template_;
    Token[][] argTokens;
    string[] proxies;
public:
    ///
    /// Estimate template param types to match the given template and call
    ///
    Type[] getEstimatedParams(NamedStruct ns, Call call, Function f) {
        this.ns        = ns;
        this.call      = call;
        this.template_ = f;
        this.argTokens = f.blueprint.argTokens;
        this.proxies   = template_.blueprint.paramNames;

        Type[string] hash;
        foreach(i, callType; call.argTypes) {
            chat("\tArg %s", i);

            if(!containsProxy(argTokens[i])) {
                chat("\t\tNo proxies");
                continue ;
            }

            Token[] tokens = argTokens[i];

            chat("\t\tCall type  = %s", callType);
            chat("\t\tArg tokens = %s", tokens.toString);

            auto buf = appender!(Tuple!(string,Type)[]);
            int tokenIndex = 0;

            matchProxiesToTypes(buf, [callType], tokens, tokenIndex);

            chat("\tbuf =");
            foreach(j, tup; buf.data) {
                chat("\t\t[%s] %s=%s", j, tup[0], tup[1]);
                addToHash(hash, tup[0], tup[1]);
            }
        }
        chat("\tHash = %s", hash);
        if(hash.length>0) {
            Type[] inOrder = new Type[proxies.length];
            for(auto n=0; n<inOrder.length; n++) {
                inOrder[n] = hash.get(proxies[n], TYPE_VOID);
            }
            chat("inOrder=%s", inOrder);
            return inOrder;
        }
        return null;
    }
    void addToHash(ref Type[string] hash, string proxy, Type type) {
        import common : containsKey;
        if(hash.containsKey(proxy)) {
            Type old = hash[proxy];
            if(areCompatible(old, type)) {
                hash[proxy] = getBestFit(old, type);
            } else {
                hash[proxy] = type;
            }
        } else {
            hash[proxy] = type;
        }
    }
    bool isArgTemplateStruct(Token[] argTokens) {
        return argTokens.any!(it=>it.type==TT.LANGLE);
    }
    bool isArgFuncPtr(Token[] argTokens) {
        return argTokens[0].type==TT.LCURLY;
    }
    bool isArgArray(Token[] argTokens) {
        return argTokens.length>1 && argTokens[0].type==TT.LSQBRACKET && argTokens[1].type==TT.COLON;
    }
    ///
    /// type =
    ///
    /// 0 Cat<Cat<int, int, int>, short, bool>
    /// 1    Cat<int, int, int>
    /// 2        int,
    /// 3        int,
    /// 4        int
    /// 5    short
    /// 6    bool
    ///
    /// Param tokens = Cat < A , B , C >
    ///
    void matchProxiesToTypes(Appender!(Tuple!(string,Type)[]) buf,
                             Type[] types,
                             Token[] argTokens,
                             ref int tokenIndex,
                             string depth="")
    {
        chat(depth~"... matching");
        chat(depth~"types  = %s", types);
        chat(depth~"tokens = %s", argTokens.toString);

        auto typeIndex = 0;

        Token getToken() {
            if(tokenIndex<argTokens.length) return argTokens[tokenIndex];
            return NO_TOKEN;
        }
        chat(depth~"index  = %s (%s)", tokenIndex, getToken().value);

        while(tokenIndex<argTokens.length && typeIndex<types.length) {
            auto token = getToken();
            auto type  = types[typeIndex];
            chat(depth~"token=%s type=%s [%s of %s]", token.value, type, typeIndex+1, types.length);

            if(token.type==TT.COMMA ||      // func or anon struct
               token.type==TT.RT_ARROW ||   // func
               token.type==TT.RCURLY ||     // func
               token.type==TT.RSQBRACKET)   // anon struct
            {
                /// Ignore these tokens
                tokenIndex++;
            } else if(isProxy(token)) {
                auto name     = token.value;
                int ptrDepth  = 0;
                while(tokenIndex<argTokens.length-1 && argTokens[tokenIndex+1].type==TT.ASTERISK) {
                    tokenIndex++;
                    ptrDepth--;
                }
                if(type.getPtrDepth + ptrDepth < 0) {
                    /// Not a match
                    break;
                }
                auto tcopy = PtrType.of(type, ptrDepth);
                buf ~= Tuple!(string,Type)(name, tcopy);
                tokenIndex++;
                typeIndex++;
            } else if(type.isAnonStruct) {
                /// [ name? type { , name? type } ]
                chat(depth~"AnonStruct");

                /// [
                if(getToken().type!=TT.LSQBRACKET) break;
                tokenIndex++;

                // todo - handle var names?

                /// go down a level
                auto children = type.getAnonStruct.memberVariableTypes();
                chat(depth~"recurse struct");
                matchProxiesToTypes(buf, children, argTokens, tokenIndex, depth~"   ");

                /// ]
                if(getToken().type!=TT.RSQBRACKET) break;
                tokenIndex++;

                typeIndex++;
            } else if(type.isArray) {
                /// [: type length ]
                chat(depth~"Array");

                /// [:
                if(getToken().type!=TT.LSQBRACKET) break;
                tokenIndex++;
                if(getToken().type!=TT.COLON) break;
                tokenIndex++;

                chat(depth~"recurse array");
                auto children = [type.getArrayType.subtype];
                matchProxiesToTypes(buf, children, argTokens, tokenIndex, depth~"   ");

                /// ]
                if(getToken().type!=TT.RSQBRACKET) break;
                tokenIndex++;

                typeIndex++;
            } else if(type.isFunction) {
                /// { type { , type } -> type }
                chat(depth~"func");

                /// {
                if(getToken().type!=TT.LCURLY) break;
                tokenIndex++;

                // todo - handle param names?

                /// go down a level
                auto children = type.getFunctionType.paramTypes.dup ~ type.getFunctionType.returnType;
                chat(depth~"recurse func");
                matchProxiesToTypes(buf, children, argTokens, tokenIndex, depth~"   ");

                typeIndex++;
            } else if(token.type==TT.IDENTIFIER) {
                /// built-int type or named struct
                chat(depth~"id");

                tokenIndex++;
                typeIndex++;
            } else {
                chat(depth~"Non-matching token: %s", getToken().value);
                break;
            }
        }
    }
    bool isProxy(Token tok) const {
        import common : contains;
        return tok.type==TT.IDENTIFIER && proxies.contains(tok.value);
    }
    bool containsProxy(Token[] tokens) const {
        foreach(tok; tokens) if(isProxy(tok)) return true;
        return false;
    }
}