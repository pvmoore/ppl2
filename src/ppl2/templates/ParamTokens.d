module ppl2.templates.ParamTokens;

import ppl2.internal;

final class ParamTokens {
private:
    Token[][] paramTokens;
    Set!string proxyNames;

    string[] regexStrings;
    string[][] proxyList;
    bool regexGenerated;
public:
    int numParams;

    this(NamedStruct ns, string[] proxyNames, Token[] tokens) {
        this.proxyNames = new Set!string;
        this.proxyNames.add(proxyNames);

        extractParams(ns, tokens);
    }
    Token[][] getTokensForAllParams() {
         return paramTokens;
    }
    Token[] getTokensForParam(int paramIndex) {
        return paramTokens[paramIndex];
    }
    string getRegexForParam(int paramIndex) {
        if(!regexGenerated) {
            generateRegexString();
        }
        return regexStrings[paramIndex];
    }
    string[] getProxiesForParam(int paramIndex) {
        if(!regexGenerated) {
            generateRegexString();
        }
        return proxyList[paramIndex];
    }
private:
    void extractParams(NamedStruct ns, Token[] tokens) {
        assert(tokens.length>0);
        assert(tokens[0].type==TT.LCURLY);
        assert(tokens[$-1].type==TT.RCURLY);

        /// Add this* as first parameter if this is a struct function template
        if(ns) {
            this.paramTokens ~= [
                tokens[0].copy("__this*", PtrType.of(ns, 1)),
                tokens[0].copy("this")
            ];
        }

        auto nav = new Tokens(null, tokens);
        nav.next;
        int arrow = nav.findInScope(TT.RT_ARROW);
        if(arrow==-1) return;

        nav.setLength(nav.index+arrow);

        int start = nav.index;

        int sq = 0, curly = 0;

        void addParam() {
            this.paramTokens ~= nav[start..nav.index];
        }

        while(nav.hasNext) {
            switch(nav.type) {
                case TT.LCURLY: curly++; nav.next; break;
                case TT.RCURLY: curly--; nav.next; break;
                case TT.LSQBRACKET: sq++; nav.next; break;
                case TT.RSQBRACKET: sq--; nav.next; break;
                case TT.COMMA:
                    /// end of param
                    if(curly==0 && sq==0) {
                        addParam();
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
            addParam();
        }
        this.numParams = paramTokens.length.as!int;
    }
    void generateRegexString() {

        //todo

        regexGenerated = true;
    }
}