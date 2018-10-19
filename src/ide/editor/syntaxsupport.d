module ide.editor.syntaxsupport;

import ide.internal;

final class PPL2SyntaxSupport : SyntaxSupport {
private:
    struct LineInfo {
        bool opensMLComment;
        bool opensDQuote;
    }
    LineInfo[] lineInfo;
    EditableContent _content;
    ppl2.Lexer lexer;
    long prevNumLines = -1;
public:
    this() {
        this.lexer = new ppl2.Lexer(null);
    }
    EditableContent content() {
        return _content;
    }
    SyntaxSupport content(EditableContent content) {
        this._content = content;

        content.contentChanged.connect((EditableContent content, EditOperation op, ref TextRange before, ref TextRange after, Object src) {
            //writefln("change %s %s",before, after);
        });

        return this;
    }

    /// return true if toggle line comment is supported for file type
    bool supportsToggleLineComment() { return false; }
    /// return true if can toggle line comments for specified text range
    bool canToggleLineComment(TextRange range) { return false; }
    /// toggle line comments for specified text range
    void toggleLineComment(TextRange range, Object source) {}

    /// return true if toggle block comment is supported for file type
    bool supportsToggleBlockComment() { return false; }
    /// return true if can toggle block comments for specified text range
    bool canToggleBlockComment(TextRange range) { return false; }
    /// toggle block comments for specified text range
    void toggleBlockComment(TextRange range, Object source) {}

    /// returns paired bracket {} () [] for char at position p,
    /// returns paired char position or p if not found or not bracket
    TextPosition findPairedBracket(TextPosition p) {
        return TextPosition(0,0);
    }

    /// returns true if smart indent is supported
    bool supportsSmartIndents() { return false; }
    /// apply smart indent after edit operation, if needed
    void applySmartIndent(EditOperation op, Object source) {}

    void updateHighlight(dstring[] lines, TokenPropString[] props, int startLine, int endLine) {
        assert(lines.length == props.length);
        writefln("updateHighlight [%s lines total] highlight lines %s..%s (%s lines)",
            lines.length,
            startLine, endLine-1,
            endLine-startLine);

        bool lineOpensMLComment(int i) {
            bool prevMLComment = i>0 && lineInfo[i-1].opensMLComment;
            string text;
            if(prevMLComment) {
                text = "/*" ~ lines[i].toUTF8;
            } else {
                text = lines[i].toUTF8;
            }
            ppl2.Token[] toks = lexer.tokenise(text, false, true);
            if(prevMLComment) {
                if(toks.length==0) return true;
            } else {
                if(toks.length==0) return false;
            }

            return toks[$-1].type==ppl2.TT.MULTILINE_COMMENT &&
                  !toks[$-1].value.endsWith("*/");
        }
        bool lineOpensDQuote(int i) {
            if(i>0 && lineInfo[i-1].opensDQuote) {

            }
            return false;
        }

        ///// update lineInfo array
        if(lineInfo.length!=lines.length) {
            lineInfo.length = lines.length;
        }


        bool prev = lineInfo[endLine-1].opensMLComment;
        writefln("prev=%s", prev);
        foreach(int i; startLine..endLine) {
            lineInfo[i].opensMLComment = lineOpensMLComment(i);
            lineInfo[i].opensDQuote    = lineOpensDQuote(i);

            //writefln("[%s] comment = %s", i, lineInfo[i].opensMLComment);
        }
        if(lineInfo[endLine-1].opensMLComment != prev) {
            foreach(int i; endLine..cast(int)lines.length) {
                lineInfo[i].opensMLComment = lineOpensMLComment(i);
                lineInfo[i].opensDQuote    = lineOpensDQuote(i);

                //writefln("[%s] comment = %s", i, lineInfo[i].opensMLComment);

                if(lineInfo[i].opensMLComment==prev) {
                    break;
                }
                endLine++;
            }
        }
        writefln("%s..%s", startLine, endLine-1);

        TokenCategory getCategory(ppl2.Token t, int j, ppl2.Token[] toks) {
            bool isFuncDecl() {
                if(j>=toks.length-1) return false;
                if(j>0 && toks[j-1].type==ppl2.TT.DOT) return false;
                if(j>0 && toks[j-1].value=="struct") return false;
                if(j>0 && toks[j-1].value=="operator") return false;
                if(toks[j+1].type==ppl2.TT.LANGLE) {
                    auto nav = new ppl2.Tokens(null, toks[j+1..$]);
                    auto i = nav.findEndOfBlock(ppl2.TT.LANGLE);
                    if(i==-1 || i>=toks.length-1 || nav.peek(i+1).type!=ppl2.TT.LCURLY) return false;
                    return true;
                }
                return toks[j+1].type==ppl2.TT.LCURLY;
            }

            switch(t.type) with(ppl2.TT) {
                case LINE_COMMENT: return TokenCategory.Comment_SingleLine;
                case MULTILINE_COMMENT: return TokenCategory.Comment_MultyLine;
                case STRING: return TokenCategory.String;
                case CHAR: return TokenCategory.Character;
                case NUMBER: return TokenCategory.Integer;
                case IDENTIFIER:
                    if(t.value=="operator") {
                        return cast(TokenCategory)(TokenCategory.Identifier+5);
                    }
                    if(ppl2.g_keywords.contains(t.value)) {
                        return TokenCategory.Keyword;
                    }
                    if(isFuncDecl()) {
                        return cast(TokenCategory)(TokenCategory.Identifier+5);
                    }
                    return TokenCategory.Identifier;
                default:
                    return TokenCategory.Op;
            }
        }

        /// Cheat. If a line has been added or removed, re-highlight the whole lot
        //if(lines.length!=prevNumLines) {
        //    prevNumLines = lines.length;
        //    startLine = 0;
        //    endLine   = cast(int)lines.length;
        //}

        bool prevLineOpensMLComment = startLine > 0 && lineInfo[startLine-1].opensMLComment;
        int lineOffset = startLine + (prevLineOpensMLComment ? -1 : 0);

        string data;
        if(prevLineOpensMLComment || endLine-startLine>1) {
            auto buf = appender!dstring;
            if(prevLineOpensMLComment) buf ~= "/*\n"d;
            foreach (j; startLine..endLine) {
                buf ~= lines[j] ~ "\n"d;
            }
            data = buf.data.toUTF8;
        } else {
            data = lines[startLine].toUTF8;
        }
        ppl2.dd("-------------");
        ppl2.Token[] toks = lexer.tokenise(data, false, true);
        ppl2.dd("tokens:", "%s".format(toks));
        //ppl2.dd("data:'%s'".format(data));

        for(int i=startLine; i<endLine; i++) {
            //ppl2.dd(i, lineOffset);
            assert(lines[i].length==props[i].length);

            auto attribs = cast(TokenCategory[])props[i];

            /// Set the whole line to comment
            foreach(ref TokenCategory t; attribs) {
                t = TokenCategory.Comment;
            }

            /// Update tokens to appropriate category
            foreach(int j, tok; toks) {
                //ppl2.dd("line:", i, "tok", tok, j, "attribs:",attribs.length, prevLineOpensMLComment);
                if(tok.line+lineOffset==i) {

                    auto c = getCategory(tok, j, toks);

                    for(auto n=tok.column; n<tok.column+tok.length; n++) {
                        assert(attribs.length>n);
                        attribs[n] = c;
                    }
                }
            }
        }

        /// If the last tokenised line contains a multiline comment then highlight everything
        //if(foundMLComment && !tokenisingWholeFile) {
        //    updateHighlight(lines, props, 0, cast(int)lines.length);
        //}

        //if(lastTokenIsMLComment) {
            /// Everything from the last line to the end of the file might now be comment.
            /// Send the rest of the file for highlighting to handle this
        //    if(endLine != lines.length) {
        //        updateHighlight(lines, props, ppl2.max(0, endLine-1), cast(int)lines.length);
        //    }
        //}
    }
}