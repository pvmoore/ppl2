module ppl2.misc.lexer;

import ppl2.internal;

final class Lexer {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    Token[] tokenise(string text, bool throwExceptions, bool includeComments) {
        auto tokens  = new Array!Token(256);
        auto buf     = new StringBuffer;
        int index    = 0;
        int line     = 0;
        int indexSOL = 0;   /// char index at start of line
        auto stack   = new Stack!int;

        char peek(int offset=0) {
            if(index+offset >= text.length) return 0;
            return text[index+offset];
        }
        bool isEOL() {
            return (peek()==13 && peek(1)==10) || peek()==10;
        }
        bool handleEOL() {
            if(peek()==13 && peek(1)==10) {
                /// EOL windows
                line++;
                index++;
                indexSOL = index+1;
                return true;
            } else if(peek()==10) {
                /// EOL unix/macOS
                line++;
                indexSOL = index+1;
                return true;
            }
            return false;
        }
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
                TT type;

                if(t.isComment)                 type = t;
                else if(isStringLiteral())      type = TT.STRING;
                else if(isCharLiteral())        type = TT.CHAR;
                else if(isNumber())             type = TT.NUMBER;
                else type = TT.IDENTIFIER;

                assert(includeComments ? true : !type.isComment);

                auto value = buf.toString().idup;
                int start  = index-cast(int)value.length;
                int column = start-indexSOL;
                assert(column>=0);

                tokens.add(Token(type, value, index-start, line, column));
                buf.clear();
            }
            if(t!=TT.NONE && !t.isComment) {
                tokens.add(Token(t, null, length, line, index-indexSOL));
            }
        }
        void addCharLiteral() {
            addToken();

            auto col = index-indexSOL;

            assert(peek()=='\'');
            buf.add(peek());
            index++;

            while(index<text.length && peek()!='\'') {
                buf.add(peek());
                if (peek()=='\\') {
                    buf.add(peek(1));
                    index++;
                }
                index++;
            }
            bool err = false;
            if(index>=text.length) {
                if(throwExceptions)
                    throw new CompilerError(module_, line, col, "Missing end quote '");
                err = true;
            }
            if(!err && parseCharLiteral(buf[1..$])==-1) {
                if(throwExceptions)
                    throw new CompilerError(module_, line, col, "Bad character literal");
                err = true;
            }
            if(err) {
                addToken();
                return;
            }

            assert(peek()=='\'');
            buf.add(peek());
            index++;
            addToken();
            index--;
        }
        void addStringLiteral() {
            /// assume src[pos] == "

            auto col = index-indexSOL;

            /// Handle possible prefix
            if(buf.length==1 && buf[0]=='r') {
                /// Include the 'r' in the string
            } else {
                addToken();
            }

            assert(peek()=='\"');
            buf.add(peek());
            index++;

            while(index<text.length && peek()!='\"') {
                buf.add(peek());
                if(peek()=='\\') {
                    buf.add(peek(1));
                    index++;
                }
                index++;
            }
            if(index>=text.length) {
                if(throwExceptions)
                    throw new CompilerError(module_, line, col, "Missing end quote \"");

                addToken();
                return;
            }

            assert(peek()=='\"');
            buf.add(peek());
            index++;
            addToken();
            index--;
        }
        void addLineComment() {
            assert(peek()=='/' && peek(1)=='/');
            /*
            // line comment */
            addToken();

            stack.push(index);
            index++;

            while(index<text.length) {
                index++;
                if(isEOL()) {
                    if(includeComments) {
                        buf.add(text[stack.pop()..index]);
                        addToken(TT.LINE_COMMENT);
                    }
                    handleEOL();
                    break;
                }
            }
            if(index>=text.length) {
                /// We ran out of text before the EOL
                if(includeComments) {
                    buf.add(text[stack.pop()..index]);
                    addToken(TT.LINE_COMMENT);
                }
            }
            stack.clear();
        }
        void addMultilineComment() {
            assert(peek()=='/' && peek(1)=='*');

            addToken();

            stack.push(index);
            //index++;

            //dd("addMultilineComment index:", index, "line:", line, "text:'%s'".format(text));

            while(index<text.length) {
                index++;

                if(peek()=='*' && peek(1)=='/') {
                    index++;

                    if(includeComments) {
                        assert(stack.length==1);
                        index++;

                        buf.add(text[stack.pop()..index]);
                        addToken(TT.MULTILINE_COMMENT);

                        index--;
                    }
                    break;
                }
                if(isEOL()) {
                    if(includeComments) {
                        assert(stack.length==1);

                        buf.add(text[stack.pop()..index]);
                        addToken(TT.MULTILINE_COMMENT);

                    }
                    handleEOL();
                    stack.push(index+1);
                }
            }
            if(index>=text.length) {
                /// We ran out of text before the end of the comment
                if(includeComments) {
                    buf.add(text[stack.pop()..index]);
                    addToken(TT.MULTILINE_COMMENT);
                }
            }
            stack.clear();
        }

        for(index=0; index<text.length; index++) {
            auto ch = text[index];
            //writefln("[%s] %s", index, ch);
            if(ch<33) {
                /// whitespace
                addToken();
                handleEOL();
            } else switch(ch) {
                case '/':
                    if(peek(1)=='/') {
                        addLineComment();
                    } else if(peek(1)=='*') {
                        addMultilineComment();
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
        addToken();
        return tokens[];
    }
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


