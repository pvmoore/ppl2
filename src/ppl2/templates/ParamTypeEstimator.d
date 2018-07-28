module ppl2.templates.ParamTypeEstimator;

import ppl2.internal;

const VERBOSE = true;

pragma(inline, true) private void chat(A...)(lazy string fmt, lazy A args) {
    static if(VERBOSE)
        dd(format(fmt, args));
}

final class ParamTypeEstimator {
private:
    string[] proxies;
    Type[string] hash;
public:
    ///
    /// Estimate template param types to match the given template and call
    ///
    Type[] getEstimatedParams(Call call, Function f) {
        this.proxies = f.blueprint.paramNames;
        this.hash.clear();

        foreach(i, callType; call.argTypes) {
            chat("\tArg %s", i);

            Token[] tokens = f.blueprint.argTokens[i];

            if(!containsProxy(tokens)) {
                chat("\t\tNo proxies");
                continue;
            }

            chat("\t\tCall type  = %s", callType);
            chat("\t\tArg tokens = %s", tokens.toString);

            int tokenIndex = 0;
            matchProxiesToTypes(TYPE_UNKNOWN, [callType], tokens, tokenIndex);
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
    ///
    /// Call arg signature:
    ///
    /// 0 Cat<Cat<int, int, [:int 10]>, {short->float}, bool>
    /// 1    Cat<int, int, [:int 10]>
    /// 2        int,
    /// 3        int,
    /// 4        [:int 10]
    /// 5            int
    /// 6    {short->float}
    /// 7        short
    /// 8        float
    /// 9    bool
    ///
    /// Param tokens = Cat < A , B , C >
    ///
    void matchProxiesToTypes(Type parent,
                             Type[] types,
                             Token[] argTokens,
                             ref int tokenIndex,
                             lazy string depth="")
    {
        chat(depth~"... matching");
        chat(depth~"types  = %s", types);
        chat(depth~"tokens = %s", argTokens.toString);

        auto typeIndex = 0;

        pragma(inline, true) Token getToken() {
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
                chat(depth~"proxy");
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
                addToHash(name, tcopy);

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
                chat(depth~"recurse struct");
                auto children = type.getAnonStruct.memberVariableTypes();
                matchProxiesToTypes(type, children, argTokens, tokenIndex, depth~"   ");

                /// ]
                if(getToken().type!=TT.RSQBRACKET) break;
                tokenIndex++;

                typeIndex++;
            } else if(type.isArray) {
                /// [: type length ]
                chat(depth~"ArrayType");

                /// [:
                if(getToken().type!=TT.LSQBRACKET) break;
                tokenIndex++;
                if(getToken().type!=TT.COLON) break;
                tokenIndex++;

                chat(depth~"recurse array");
                auto children = [type.getArrayType.subtype];
                matchProxiesToTypes(type, children, argTokens, tokenIndex, depth~"   ");

                /// ]
                if(getToken().type!=TT.RSQBRACKET) break;
                tokenIndex++;

                typeIndex++;
            } else if(type.isFunction) {
                /// { name? type { , name? type } -> type }
                chat(depth~"FunctionType");

                /// {
                if(getToken().type!=TT.LCURLY) break;
                tokenIndex++;

                // todo - handle param names?

                /// go down a level
                chat(depth~"recurse func");
                auto children = type.getFunctionType.paramTypes.dup ~ type.getFunctionType.returnType;
                matchProxiesToTypes(type, children, argTokens, tokenIndex, depth~"   ");

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
    void addToHash(string proxy, Type type) {
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
    bool isProxy(Token tok) const {
        import common : contains;
        return tok.type==TT.IDENTIFIER && proxies.contains(tok.value);
    }
    bool containsProxy(Token[] tokens) const {
        foreach(tok; tokens) if(isProxy(tok)) return true;
        return false;
    }
}