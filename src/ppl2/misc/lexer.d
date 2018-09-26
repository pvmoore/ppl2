module ppl2.misc.lexer;

import ppl2.internal;

final class Lexer {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    Token[] tokenise(string text) {
        log("Tokenising %s", module_.canonicalName);
        auto tokens   = appender!(Token[]);
        auto buf      = new StringBuffer;
        auto index    = 0;
        auto line     = 1;
        auto indexSOL = 0;   /// char index at start of line

        bool isNumber() {
            auto firstChar = buf[0];
            return firstChar =='-' || (firstChar >= '0' && firstChar <= '9');
        }
        bool isStringLiteral() {
            if(buf[0]=='\"') return true;
            if(buf.length>1 && buf[0..2] == "r\"") return true;
            if(buf.length>3 && buf[0..4] == "u16\"") return true;
            if(buf.length>3 && buf[0..4] == "u32\"") return true;
            return false;
        }
        bool isCharLiteral() {
            return buf[0]=='\'';
        }
        void addToken(TT t = TT.NONE, int length=1) {
            if(buf.length>0) {
                auto type = TT.IDENTIFIER;
                if(isStringLiteral()) type = TT.STRING;
                else if(isCharLiteral()) type = TT.CHAR;
                else if(isNumber()) type = TT.NUMBER;

                auto value = buf.toString().idup;
                auto start = index-cast(int)value.length;
                auto column = start-indexSOL;
                tokens ~= Token(type, value, start, index-1, line, column);
                buf.clear();
            }
            if(t!=TT.NONE) {
                tokens ~= Token(t, null, index, index+length-1, line, index-indexSOL);
            }
        }

        char peek(int offset=0) {
            if(index+offset >= text.length) return 0;
            return text[index+offset];
        }
        void addCharLiteral() {
            /// assume peek(0) == '
            addToken();

            auto col = index-indexSOL;

            buf.add(peek());
            index++;
            while(index<text.length && peek()!='\'') {
                buf.add(peek());
                if(peek()=='\\') {
                    buf.add(peek(1));
                    index++;
                }
                index++;
            }
            if(parseCharLiteral(buf[1..$])==-1) {
                throw new CompilerError(module_, line, col, buf[1..$]);
            }

            buf.add(peek());
            addToken();
        }
        void addStringLiteral() {
            /// assume src[pos] == "

            /// Handle possible prefix
            if(buf.length==1 && buf[0]=='r') {
                /// Include the 'r' in the string
            } else {
                addToken();
            }

            buf.add(peek());
            index++;
            while(index<text.length && peek()!='\"') { // "
                buf.add(peek());
                if(peek()=='\\') {
                    buf.add(peek(1));
                    index++;
                }
                index++;
            }
            buf.add(peek());
            addToken();
        }

        for(index=0; index<text.length; index++) {
            auto ch = text[index];
            //writefln("[%s] %s", index, ch);
            if(ch<33) {
                /// whitespace
                addToken();

                if(ch==10 || ch==13) {
                    line++;
                    if(peek(1)==10) index++;
                    indexSOL = index+1;
                }
            } else switch(ch) {
                case '/':
                    if(peek(1)=='/') {
                        /*
                        // line comment */
                        addToken();
                        index++;

                        while(index<text.length) {
                            index++;
                            if(peek(0)==13 || peek(0)==10) {
                                line++;
                                if(peek(1)==10) index++;
                                indexSOL = index+1;
                                break;
                            }
                        }
                    } else if(peek(1)=='*') {
                        /// multiline comment
                        addToken();
                        index++;

                        while(index<text.length) {
                            index++;
                            if (peek(0)==10) line++;
                            if (peek(0)=='*' && peek(1)=='/') {
                                index++;
                                break ;
                            }
                        }
                    } else if(peek(1)=='=') {
                        addToken(TT.DIV_ASSIGN, 2);
                        index++;
                    } else {
                        addToken(TT.DIV);
                    }
                    break;
                case '\'':
                    addCharLiteral();
                    break;
                case '"':
                    addStringLiteral();
                    break;
                case '*':
                    if(peek(1)=='=') {
                        addToken(TT.MUL_ASSIGN, 2);
                        index++;
                    } else {
                        addToken(TT.ASTERISK);
                    }
                    break;
                case '%':
                    if(peek(1)=='=') {
                        addToken(TT.MOD_ASSIGN, 2);
                        index++;
                    } else {
                        addToken(TT.PERCENT);
                    }
                    break;
                case '{':
                    addToken(TT.LCURLY);
                    break;
                case '}':
                    addToken(TT.RCURLY);
                    break;
                case '[':
                    addToken(TT.LSQBRACKET);
                    break;
                case ']':
                    addToken(TT.RSQBRACKET);
                    break;
                case '(':
                    addToken(TT.LBRACKET);
                    break;
                case ')':
                    addToken(TT.RBRACKET);
                    break;
                case '<':
                    if(peek(1)=='>') {
                        addToken(TT.COMPARE, 2);
                        index++;
                    } else if(peek(1)=='=') {
                        addToken(TT.LTE, 2);
                        index++;
                    } else if(peek(1)=='<' && peek(2)=='=') {
                        addToken(TT.SHL_ASSIGN, 3);
                        index+=2;
                    } else if(peek(1)=='<') {
                        addToken(TT.SHL, 2);
                        index++;
                    } else {
                        addToken(TT.LANGLE);
                    }
                    break;
                case '>':
                    if(peek(1)=='=') {
                        addToken(TT.GTE, 2);
                        index++;
                    } else if(peek(1)=='>' && peek(2)=='=') {
                        addToken(TT.SHR_ASSIGN, 3);
                        index+=2;
                    } else if(peek(1)=='>' && peek(2)=='>' && peek(3)=='=') {
                        addToken(TT.USHR_ASSIGN, 4);
                        index+=3;
                    } else {
                        /// Keep '>' tokens separate so that we can parse
                        /// List<List<int>> correctly/
                        /// We will need to merge tokens when determining >> and >>> operators.
                        ///
                    //} else if(peek(1)=='>' && peek(2)=='>' ) {
                    //    addToken(TT.USHR, 3);
                    //    index+=2;
                    //} else if(peek(1)=='>') {
                    //    addToken(TT.SHR, 2);
                    //    index++;
                    //} else {
                        addToken(TT.RANGLE);
                    }
                    break;
                case '=':
                    if(peek(1)=='=') {
                        addToken(TT.BOOL_EQ, 2);
                        index++;
                    } else {
                        addToken(TT.EQUALS);
                    }
                    break;
                case '!':
                    addToken(TT.EXCLAMATION);
                    break;
                case '&':
                    if(peek(1)=='=') {
                        addToken(TT.BIT_AND_ASSIGN, 2);
                        index++;
                    } else {
                        addToken(TT.AMPERSAND);
                    }
                    break;
                case '^':
                    if(peek(1)=='=') {
                        addToken(TT.BIT_XOR_ASSIGN, 2);
                        index++;
                    } else {
                        addToken(TT.HAT);
                    }
                    break;
                case '|':
                    if(peek(1)=='=') {
                        addToken(TT.BIT_OR_ASSIGN, 2);
                        index++;
                    } else {
                        addToken(TT.PIPE);
                    }
                    break;
                case ':':
                    if(peek(1)==':') {
                        addToken(TT.DBL_COLON, 2);
                        index++;
                    } else {
                        addToken(TT.COLON);
                    }
                    break;
                case ';':
                    addToken(TT.SEMICOLON);
                    break;
                case ',':
                    addToken(TT.COMMA);
                    break;
                case '+':
                    if(peek(1)=='=') {
                        addToken(TT.ADD_ASSIGN, 2);
                        index++;
                    } else {
                        addToken(TT.PLUS);
                    }
                    break;
                case '-':
                    if(buf.length == 0 && peek(1).isDigit) {
                        buf.add(ch);
                    } else if(peek(1)=='=') {
                        addToken(TT.SUB_ASSIGN, 2);
                        index++;
                    } else if(peek(1)=='>') {
                        addToken(TT.RT_ARROW, 2);
                        index++;
                    } else {
                        addToken(TT.MINUS);
                    }
                    break;
                case '.':
                    if(buf.length > 0 && isNumber() && peek(1).isDigit) {
                        buf.add(ch);
                    } else {
                        addToken(TT.DOT);
                    }
                    break;
                case '?':
                    addToken(TT.QMARK);
                    break;
                case '~':
                    addToken(TT.TILDE);
                    break;
                //case '#':
                //    addToken(TT.HASH);
                //    break;
                case '$':
                    addToken(TT.DOLLAR);
                    break;
                case '@':
                    addToken(TT.AT);
                    break;
                default:
                    buf.add(ch);
                    break;
            }
        }
        log("... found %s tokens", tokens.data.length);
        dumpTokens(tokens.data);
        return tokens.data;
    }
private:
    void dumpTokens(Token[] tokens) {
        if(!getConfig().logTokens) return;

        auto f = new FileLogger(getConfig().targetPath~"tok/"~module_.canonicalName~".tok");
        foreach(i, t; tokens) {
            f.log("[%s] %s", i, t);
        }
    }
}
//=========================================================================================
string toSimpleString(Token[] tokens) {
    auto buf = new StringBuffer;
    foreach(i, t; tokens) {
        if(t.type==TT.IDENTIFIER) {
            buf.add(t.value);
        } else {
            buf.add(t.type.toString());
        }
        buf.add(" ");
    }
    return buf.toString();
}


