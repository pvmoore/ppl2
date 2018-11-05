module ppl2.templates.ParamTypeEstimator;

import ppl2.internal;

private const VERBOSE = false;

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

        chat("-------------- checking template %s(%s)", f.name, f.blueprint.argTokens.map!(it=>it.toSimpleString));

        foreach(i, callType; call.argTypes) {
            chat("\tArg %s", i);

            Token[] tokens = f.blueprint.argTokens[i];

            if(!containsProxy(tokens)) {
                chat("\t\tNo proxies");
                continue;
            }

            chat("\t\tCall type  = %s", callType);
            chat("\t\tArg tokens = %s", tokens.toSimpleString);

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
    ///  Cat<Cat<int, int, int*[10]*[2]*>, {short->float}, bool>
    ///     Cat<int, int, int[10][2]>
    ///         int,
    ///         int,
    ///         int*[10]*[2]*
    ///            int*[10]*, // subtype
    ///     {short->float}
    ///         short
    ///         float
    ///     bool
    ///
    /// Param tokens = Cat < A , B , C >
    ///
    void matchProxiesToTypes(Type parent,
                             Type[] types,
                             Token[] argTokens,
                             ref int tokenIndex,
                             lazy string depth="    ")
    {
        chat(depth~"... matching arg types: %s, tokens: %s", types, argTokens.toSimpleString);

        auto typeIndex = 0;

        Token getToken(int offset=0) {
            if(tokenIndex+offset<argTokens.length) return argTokens[tokenIndex+offset];
            return NO_TOKEN;
        }
        //bool isLastToken() { return tokenIndex+1 == argTokens.length; }
        //bool isLastType()  { return typeIndex+1  == types.length; }
        bool foundProxy(Type type, Token token) {
            chat(depth~"proxy");
            auto name     = token.value;
            int ptrDepth  = 0;

            while(tokenIndex<argTokens.length-1 && argTokens[tokenIndex+1].type==TT.ASTERISK) {
                tokenIndex++;
                ptrDepth--;
            }
            if(type.getPtrDepth + ptrDepth < 0) {
                /// Not a match
                return false;
            }
            auto tcopy = PtrType.of(type, ptrDepth);
            addToHash(name, tcopy);

            tokenIndex++;
            typeIndex++;
            return true;
        }
        //chat(depth~"index = %s (%s)", tokenIndex, getToken().value);

        while(tokenIndex<argTokens.length && typeIndex<types.length) {
            auto token = getToken();
            auto type  = types[typeIndex];
            chat(depth~"token=%s type=%s (%s of %s)", token.value, type, typeIndex+1, types.length);

            if(token.type==TT.COMMA ||      // func or anon struct
               token.type==TT.RT_ARROW ||   // func
               token.type==TT.RCURLY ||     // func
               token.type==TT.RSQBRACKET)   // anon struct
            {
                /// Ignore these tokens
                tokenIndex++;
            } else if(type.isArray) {
                /// type*[length]*[length2]* etc...
                chat(depth~"ArrayType");

                auto arrayType = type.getArrayType;
                int lSqBrOffset = 1;

                bool isFollowedBySqBr() {
                    while(getToken(lSqBrOffset).type==TT.ASTERISK) lSqBrOffset++;

                    return getToken(lSqBrOffset).type==TT.LSQBRACKET;
                }

                //if(isFollowedBySqBr()) {
                //
                //
                //    chat(depth~"recurse array subtype");
                //    auto children = [arrayType.subtype];
                //    matchProxiesToTypes(type, children, argTokens, tokenIndex, depth~"   ");
                //
                //
                //} else {
                //    tokenIndex++;
                //}

                if(isProxy(token)) {
                    if(isFollowedBySqBr()) {
                        /// Check the count if possible before adding the proxy

                        chat(depth~"recurse array subtype");
                        auto children = [arrayType.subtype];
                        matchProxiesToTypes(type, children, argTokens, tokenIndex, depth~"   ");

                    } else {
                        if(!foundProxy(type, token)) break;
                        continue;
                    }
                } else {
                    /// Skip non-proxy type name
                    tokenIndex++;
                }

                /// [
                if(getToken().type!=TT.LSQBRACKET) break;
                tokenIndex++;

                /// count expression
                if(getToken().type==TT.NUMBER) {
                    if(getToken().value != arrayType.countAsInt.to!string) {
                        chat(depth~"incorrect array length (%s != %s)", getToken().value, arrayType.countAsInt);
                        break;
                    }
                } else {
                    /// skip tokens until ']'
                    while(getToken()!=NO_TOKEN && getToken().type!=TT.RSQBRACKET) tokenIndex++;
                }

                /// ]
                if(getToken().type!=TT.RSQBRACKET) break;
                tokenIndex++;

                typeIndex++;
            } else if(isProxy(token)) {
                if(!foundProxy(type, token)) break;
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
                chat(depth~"id '%s'", token.value);

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