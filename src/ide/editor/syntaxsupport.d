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

    void updateHighlight(dstring[] lines, TokenPropString[] props, int changeStartLine, int changeEndLine) {
        assert(lines.length == props.length);
        //writefln("{ updateHighlight (%s lines) %s %s",
        //    changeEndLine-changeStartLine, changeStartLine, changeEndLine);

        // todo - update lineInfo array

        TokenCategory category(ppl2.Token t) {
            switch(t.type) with(ppl2.TT) {
                case STRING: return TokenCategory.String;
                case CHAR: return TokenCategory.Character;
                case NUMBER: return TokenCategory.Integer;
                case IDENTIFIER:
                    if(ppl2.g_keywords.contains(t.value)) {
                        return TokenCategory.Keyword;
                    }
                    return TokenCategory.Identifier;
                default: return TokenCategory.Op;
            }
        }

        for(int i=changeStartLine; i<changeEndLine; i++) {
            assert(lines[i].length==props[i].length);
            if(lines[i].length==0) continue;

            auto tokens = cast(TokenCategory[])props[i];

            try{
                ppl2.Token[] toks = lexer.tokenise(lines[i].toUTF8, null, false);

                /// Set the whole line to comment
                foreach(ref TokenCategory t; tokens) {
                    t = TokenCategory.Comment;
                }
                /// Update tokens to appropriate category
                foreach (tok; toks) {
                    auto c = category(tok);

                    for(auto n=tok.column; n<tok.column+tok.length; n++) {
                        assert(tokens.length>n);
                        tokens[n] = c;
                    }
                }

                import std.string : indexOf;
                if (lines[i].indexOf("\'")!=-1)
                    writefln("\tLINE[%s]:'%s' %s %s", i, lines[i], props[i], toks);
            }catch(Exception e) {
                // ignore
            }
        }
        //writefln("}");
        flushConsole();
    }
}