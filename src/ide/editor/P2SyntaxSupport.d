module ide.editor.P2SyntaxSupport;

import ide.internal;

final class PPL2SyntaxSupport : SyntaxSupport, BuildListener {
private:
    struct LineInfo {
        bool opensMLComment;
        bool opensDQuote;
        int openBraceCount;
        string content;

        bool opensSomething() {
            return opensMLComment || opensDQuote;
        }
    }
    struct Error {
        int line;
        int start;
        int end;
    }
    string moduleCanonicalName;
    EditableContent _content;
    ppl2.Lexer lexer;
    Array!LineInfo lineInfo;
    Array!Error errors;
    bool opInProgress;
public:
    this(string moduleCanonicalName) {
        this.moduleCanonicalName = moduleCanonicalName;
        this.lexer    = new ppl2.Lexer(null);
        this.lineInfo = new Array!LineInfo(1024);
        this.errors   = new Array!Error;
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
    /// BuildListener
    void buildSucceeded(ppl2.BuildState state) {
        /// Remove error highlights

        //writefln("Removing errors");
        foreach(e; errors.values) {

        }
        errors.clear();
    }
    void buildFailed(ppl2.BuildState state) {
        /// Add error highlights

        foreach(err; state.getErrors()) {
            /// Not sure how to update the error line so that it re-highlights

            //content.performOperation(new EditOperation(), this);
            //content.updateTokenProps(ce.line, ce.line+1);
        }
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
    bool supportsSmartIndents() { return true; }

    /// apply smart indent after edit operation, if needed
    void applySmartIndent(EditOperation op, Object source) {
        if(opInProgress) return;

        //writefln("applySmartIndent(%s) %s line %s", op.action, source, op.newRange.end.line); flushConsole();
        if(op.isInsertNewLine) {
            int line = op.newRange.end.line;
            if(line == 0) {
                return;
            }
            auto count = lineInfo[line].openBraceCount;
            dstring txt = "    ".repeat(count).toUTF32;

            EditOperation op2 = new EditOperation(
                EditAction.Replace,
                TextRange(TextPosition(line, 0), TextPosition(line, 0)),
                [txt]);

            opInProgress = true;
            _content.performOperation(op2, source);
            opInProgress = false;
        } else if(op.singleChar == '}') {
            int line = op.newRange.end.line;
            int pos  = op.newRange.end.pos;
            if(pos < 4) return;

            TextLineMeasure lineMeasurement = _content.measureLine(line);

            if(lineMeasurement.firstNonSpace != pos-1) return;

            dstring txt = "}"d;
            EditOperation op2 = new EditOperation(
                EditAction.Replace,
                TextRange(TextPosition(line, pos-5), TextPosition(line, pos)),
                [txt]);

            opInProgress = true;
            _content.performOperation(op2, source);
            opInProgress = false;
        }
    }

    void updateHighlight(dstring[] lines, TokenPropString[] props, int startLine, int endLine) {
        assert(lines.length == props.length);
        assert(startLine    != endLine);
        assert(endLine      != 0);

        //writefln("====================================================");
        //writefln("updateHighlight [%s lines total] highlight lines %s..%s (%s lines)",
        //    lines.length,
        //    startLine, endLine-1,
        //    endLine-startLine); flushConsole();

        updateLineInfo(lines, startLine, endLine);

        bool prevLineOpensSomething = startLine > 0 && lineInfo[startLine-1].opensSomething;
        int lineOffset              = startLine + (prevLineOpensSomething ? -1 : 0);

        string data;
        if(prevLineOpensSomething || endLine-startLine>1) {
            auto buf = appender!dstring;
            if(prevLineOpensSomething) {
                if(lineInfo[startLine-1].opensDQuote) buf ~= "\"\n"d;
                if(lineInfo[startLine-1].opensMLComment) buf ~= "/*\n"d;
            }
            foreach(j; startLine..endLine) {
                buf ~= lines[j] ~ "\n"d;
            }
            data = buf.data.toUTF8;
        } else {
            data = lines[startLine].toUTF8;
        }

        ppl2.Token[] toks = lexer.tokenise!true(data);
        //ppl2.dd("tokens:", "%s".format(toks));
        //ppl2.dd("data:'%s'".format(data));

        for(int i=startLine; i<endLine; i++) {
            //ppl2.dd(i, lineOffset);
            assert(lines[i].length==props[i].length);

            auto attribs = cast(TokenCategory[])props[i];

            /// Set the whole line to comment
            foreach(ref TokenCategory t; attribs) {
                t = TokenCategory.Comment;
            }

            foreach(e; errors) {

            }

            /// Update tokens to appropriate category
            foreach(int j, tok; toks) {
                //ppl2.dd("line:", i, "tok", tok, j, "attribs:",attribs.length);
                if(tok.line+lineOffset==i) {

                    auto c = getCategory(tok, j, toks);

                    for(auto n=tok.column; n<tok.column+tok.length; n++) {
                        assert(attribs.length>n);
                        attribs[n] = c;
                    }
                }
            }
            lineInfo[i].content = lines[i].toUTF8;
        }

        //foreach(i; 0..lines.length) {
        //    writefln("[%s] %s", i, lineInfo[i]);
        //}
        //flushConsole();
    }
private:
    void updateLineInfo(dstring[] lines, int startLine, ref int endLine) {
        //writefln("updateLineInfo %s %s", lineInfo.length, lines.length); flushConsole();

        ///
        /// Add or remove lineInfo lines as necessary
        ///
        if(lineInfo.length < lines.length) {
            /// Add lines from startLine
            for(int i=startLine; lineInfo.length < lines.length; i++) {
                lineInfo.insertAt(i, LineInfo());
            }
        } else if(lineInfo.length > lines.length) {
            /// Remove lines from startLine
            while(lineInfo.length > lines.length) {
                lineInfo.removeAt(startLine+1);
            }
        }
        assert(lineInfo.length==lines.length);

        bool startLineOpensMLComment = startLine > 0 && lineInfo[startLine].opensMLComment;
        bool startLineOpensDQuote    = startLine > 0 && lineInfo[startLine].opensDQuote;
        int startOpenBraceCount      = startLine > 0 ? lineInfo[startLine].openBraceCount : 0;
        //writefln("open[%s]=%s", startLine, startLineOpensSomething);

        foreach(int i; startLine..endLine) {
            parseLine(i, lines);
        }

        /// Extend downwards until any opened dquotes or multiline
        /// comments have been closed or vice versa

        bool changed(int lineNum) {
            return lineInfo[lineNum].opensMLComment != startLineOpensMLComment ||
                   lineInfo[lineNum].opensDQuote    != startLineOpensDQuote ||
                   lineInfo[lineNum].openBraceCount != startOpenBraceCount;
        }

        if(changed(endLine-1)) {

            foreach(int i; endLine..cast(int)lines.length) {
                parseLine(i, lines);

                if(!changed(i)) break;

                endLine++;
            }
        }
    }
    void parseLine(int i, dstring[] lines) {
        import ppl2 : TT;

        bool prevMLComment = i>0 && lineInfo[i-1].opensMLComment;
        bool prevDQuote    = i>0 && lineInfo[i-1].opensDQuote;
        int openBraceCount = i>0 ? lineInfo[i-1].openBraceCount : 0;
        /// They can't both be true
        assert(prevMLComment==false || prevDQuote==false);

        string text;
        if(prevMLComment) {
            text = "/*" ~ lines[i].toUTF8;
        } else if(prevDQuote) {
            text = "\"" ~ lines[i].toUTF8;
        } else {
            text = lines[i].toUTF8;
        }
        auto toks = lexer.tokenise!true(text);
        //ppl2.dd("toks=", toks, toks.length>0 ? "'"~toks[0].value~"'" : "");

        bool opensMLComment = false;
        bool opensDQuote    = false;

        if(toks.length==0) {
            opensMLComment = prevMLComment;
            opensDQuote    = prevDQuote;
        } else {
            auto last = toks[$-1];
            opensMLComment = last.type==TT.MULTILINE_COMMENT && !last.value.endsWith("*/");

            if(last.type==TT.STRING) {
                if(!last.value.endsWith("\"")) {
                    opensDQuote = true;
                } else {
                    /// line ends with "
                    int numQuotes = countDQuotes(last.value);
                    opensDQuote = numQuotes==1;
                }
            }

            foreach(t; toks) {
                if(t.type==TT.LCURLY) { openBraceCount++; }
                else if(t.type==TT.RCURLY) { openBraceCount--; }
            }
        }
        lineInfo[i].opensMLComment = opensMLComment;
        lineInfo[i].opensDQuote    = opensDQuote;
        lineInfo[i].openBraceCount = openBraceCount;
    }
    int countDQuotes(string line) {
        int count = 0;
        for(auto i=0; i<line.length; i++) {
            auto c = line[i];

            if(c=='\\' && i<line.length-1 && line[i+1]=='\"') {
                i++;
            } else if(c=='\"') {
                count++;
            }
        }
        return count;
    }
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
}
