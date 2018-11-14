module ide.editor.IRSyntaxSupport;

import ide.internal;

final class IRSyntaxSupport : SyntaxSupport {
private:
    EditableContent _content;
public:
    this() {
        initialiseKeywords();
    }
    EditableContent content() {
        return _content;
    }
    SyntaxSupport content(EditableContent content) {
        this._content = content;
        return this;
    }
    /// return true if toggle line comment is supported for file type
    bool supportsToggleLineComment() {
        return false;
    }
    /// return true if can toggle line comments for specified text range
    bool canToggleLineComment(TextRange range) {
        return false;
    }
    /// toggle line comments for specified text range
    void toggleLineComment(TextRange range, Object source) {}

    /// return true if toggle block comment is supported for file type
    bool supportsToggleBlockComment() {
        return false;
    }
    /// return true if can toggle block comments for specified text range
    bool canToggleBlockComment(TextRange range) {
        return false;
    }
    /// toggle block comments for specified text range
    void toggleBlockComment(TextRange range, Object source) {}

    /// returns paired bracket {} () [] for char at position p,
    /// returns paired char position or p if not found or not bracket
    TextPosition findPairedBracket(TextPosition p) {
        return TextPosition(0,0);
    }

    /// returns true if smart indent is supported
    bool supportsSmartIndents() {
        return false;
    }
    /// apply smart indent after edit operation, if needed
    void applySmartIndent(EditOperation op, Object source) {}

    void updateHighlight(dstring[] lines, TokenPropString[] props, int startLine, int endLine) {
        foreach(i; startLine..endLine) {
            tokeniseLine(i, lines[i], cast(TokenCategory[])props[i]);
        }
    }
private:
    Set!dstring keywords;
    void initialiseKeywords() {
        keywords = new Set!dstring;
        keywords.add([
            "add",
            "align",
            "alloca",
            "and",
            "ashr",
            "attributes",
            "available_externally",
            "bitcast",
            "br",
            "call",
            "constant",
            "datalayout",
            "declare",
            "define",
            "eq",           // icmp
            "exact",
            "extractvalue",
            "fadd",
            "fastcc",
            "fcmp",
            "fpext",
            "fptosi",
            "fptoui",
            "fptrunc",
            "fsub",
            "getelementptr",
            "global",
            "icmp",
            "inbounds",
            "internal",
            "inttoptr",
            "label",
            "load",
            "local_unnamed_addr",
            "lshr",
            "mul",
            "ne",           // icmp
            "noalias",
            "nocapture",    // attr
            "nonnull",      // attr
            "nsw",          // (no signed wrap)
            "nuw",          // (no unsigned wrap)
            "oeq",          // fcmp
            "oge",          // fcmp
            "ogt",          // fcmp
            "ole",          // fcmp
            "olt",          // fcmp
            "one",          // fcmp
            "or",
            "ord",          // fcmp
            "phi",
            "ptrtoint",
            "ret",
            "sdiv",
            "sext",
            "sitofp",
            "shl",
            "sge",          // icmp (signed greater than or equal)
            "sgt",          // icmp (signed greater than)
            "sle",          // icmp (signed less than or equal)
            "slt",          // icmp (signed less than)
            "srem",
            "store",
            "sub",
            "switch",
            "tail",
            "target",
            "to",
            "triple",
            "trunc",
            "type",
            "udiv",
            "ueq",          // fcmp
            "uitofp",
            "uge",          // fcmp (unsigned greater than or equal)
            "ugt",          // fcmp (unsigned greater than)
            "ule",          // icmp (unsigned less than or equal)
            "ult",          // icmp (unsigned less than
            "une",          // fcmp (unordered or not equal)
            "unnamed_addr",
            "uno",          // fcmp (unordered - either nans)
            "urem",
            "writeonly",    // attr
            "xor",
            "zeroinitializer",
            "zext"
        ]);
    }
    void tokeniseLine(int lineNum, dstring line, TokenCategory[] attribs) {
        int i     = 0;
        int start = 0;

        dchar peek(int offset=0) {
            if(i+offset>=line.length) return 0;
            return line[i+offset];
        }
        bool isNumber(dstring s) {
            if(s=="null" || s=="true" || s=="false" || s=="undef") return true;
            if(s[0]=='-' && s.length>1) return s[1] >= '0' && s[1] <='9';
            return s[0] >= '0' && s[0] <='9';
        }
        bool isType(dstring s) {
            if(s.length<2) return false;
            if(s=="float" || s=="double") return true;
            if(s.startsWith("i") || s.startsWith("f")) {
                return isNumber(s[1..$]);
            }
            return s=="void"d;
        }
        bool isLabel(dstring s) {
            return s[$-1]==':';
        }
        auto getCategory(dstring s) {
            if(s[0]=='@') return TokenCategory.Identifier_Member;
            if(s[0]=='%') return TokenCategory.Identifier_Local;
            if(keywords.contains(line[start..i])) return TokenCategory.Keyword;
            if(isNumber(s)) return TokenCategory.Integer;
            if(isType(s)) return cast(TokenCategory)(TokenCategory.Identifier | 5);
            if(isLabel(s)) return cast(TokenCategory)(TokenCategory.Identifier | 6);
            return TokenCategory.Identifier;
        }
        void token(TokenCategory cat = TokenCategory.WhiteSpace, int len = 1) {
            if(start<i) {
                auto c = getCategory(line[start..i]);
                foreach(n; start..i) {
                    attribs[n] = c;
                }
            }
            if(cat!=TokenCategory.WhiteSpace) {
                foreach(n; i..i+len) {
                    attribs[n] = cat;
                }
            }
            start = i+len;
        }
        void lineComment() {
            foreach(n; i..line.length) {
                attribs[n] = TokenCategory.Comment_SingleLine;
            }
        }
        for(; i<line.length; i++) {
            auto ch = peek();
            switch(ch) {
                case 0:..case 32:
                    token();
                    break;
                case ';':
                    lineComment();
                    return;
                case '\"':
                    import std.string : indexOf;
                    auto idx = line[i+1..line.length].indexOf("\"").as!int;
                    assert(idx!=-1);
                    i += idx + 1;
                    break;
                case '(':
                case ')':
                case '[':
                case ']':
                case '{':
                case '}':
                case '<':
                case '>':
                case ',':
                case '=':
                case '*':
                    token(TokenCategory.Op, 1);
                    break;
                default:
                    break;
            }
        }
        token();
        flushConsole();
    }
}