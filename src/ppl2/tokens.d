module ppl2.tokens;

import ppl2.internal;

final class TokenNavigator {
private:
    Token[] tokens;
    int pos = 0;
    Stack!int marks;
public:
    Module module_;
    Access access = Access.PRIVATE;

    this(Module module_, Token[] tokens) {
        this.module_ = module_;
        this.tokens  = tokens;
        this.marks   = new Stack!int;
    }
    void reset() {
        pos = 0;
        marks.clear();
        access = Access.PRIVATE;
    }
    //=======================================
    void markPosition() {
        marks.push(pos);
    }
    void resetToMark() {
        pos = marks.pop();
    }
    void discardMark() {
        marks.pop();
    }
    //=======================================
    int index() {
        return pos;
    }
    int line() const { return get().line; }
    int column() const { return get().column; }
    Token get() const {
        if(pos >= tokens.length) return NO_TOKEN;
        return tokens[pos];
    }
    // Inclusive range
    Token[] get(int start, int end) {
        return tokens[start..end+1];
    }
    TT type() const {
        return get().type;
    }
    string value() const {
        return get().value;
    }
    Token peek(int offset) {
        if(pos+offset < 0 || pos+offset >= tokens.length) return NO_TOKEN;
        return tokens[pos+offset];
    }
    bool isKeyword(string k) {
        return type()==TT.IDENTIFIER && value()==k;
    }
    //=======================================
    void next(int numToMove=1) {
        pos += numToMove;
    }
    void prev(int numToMove=1) {
        pos -= numToMove;
    }
    void skip(TT t) {
        if(type()!=t) throw new CompilerError(Err.BAD_SYNTAX, this,
                                    "Expecting %s".format(t));
        next();
    }
    void skip(string kw) {
        if(value()!=kw) throw new CompilerError(Err.BAD_SYNTAX, this,
                                    "Expecting %s".format(kw));
        next();
    }
    bool typeIn(TT[] types...) {
        auto ty = type();
        foreach(t; types) if(t==ty) return true;
        return false;
    }
    void expect(TT[] types...) {
        foreach(t; types) if(type()==t) return;
        throw new CompilerError(Err.BAD_SYNTAX, this,
                    "Expecting one of %s".format(types));
    }
    bool hasNext() {
        return pos < cast(int)tokens.length - 1;
    }
    int find(TT t) {
        int offset = 0;
        while(pos+offset < tokens.length) {
            if(peek(offset).type==t) return offset;
            offset++;
        }
        return -1;
    }
    ///
    /// Find a type in the current scope. If the scope ends by reaching
    /// an unopened close bracket of any type then it will return -1;
    ///
    int findInCurrentScope(TT t, int offset=0) {
        int cbr = 0, sqbr = 0, br = 0;
        while(pos+offset < tokens.length) {
            auto ty = peek(offset).type;
            if(cbr+sqbr+br==0 && ty==t) return offset;
            switch(ty) {
                case TT.LBRACKET: br++; break;
                case TT.RBRACKET: if(--br<0) return -1; break;
                case TT.LCURLY: cbr++; break;
                case TT.RCURLY: if(--cbr<0) return -1; break;
                case TT.LSQBRACKET: sqbr++; break;
                case TT.RSQBRACKET: if(--sqbr<0) return -1; break;
                default: break;
            }
            offset++;
        }
        return -1;
    }
    ///
    /// Find any of keywords in the current scope. If the scope ends by reaching
    /// an unopened close bracket of any type then it will return -1;
    ///
    int findInScope(Set!string keywords) {
        int offset = 0;
        int cbr = 0, sqbr = 0, br = 0;
        while(pos+offset < tokens.length) {
            auto tok = peek(offset);
            auto ty  = tok.type;
            if(cbr+sqbr+br==0 && ty==TT.IDENTIFIER && keywords.contains(tok.value)) return offset;
            switch(ty) {
                case TT.LBRACKET: br++; break;
                case TT.RBRACKET: if(--br<0) return -1; break;
                case TT.LCURLY: cbr++; break;
                case TT.RCURLY: if(--cbr<0) return -1; break;
                case TT.LSQBRACKET: sqbr++; break;
                case TT.RSQBRACKET: if(--sqbr<0) return -1; break;
                default: break;
            }
            offset++;
        }
        return -1;
    }
    ///
    /// Returns the pos of the closing bracket.
    /// Assumes we are currently at the opening bracket or before it.
    /// Returns -1 if the end bracket is not found.
    ///
    int findEndOfBlock(TT brtype, int startOffset=0) {
        auto open  = brtype;
        auto close = open==TT.LBRACKET   ? TT.RBRACKET   :
                     open==TT.LSQBRACKET ? TT.RSQBRACKET :
                     open==TT.LCURLY     ? TT.RCURLY     : TT.NONE;
        int braces = 0;
        for(int offset=startOffset; pos+offset < tokens.length; offset++) {
            auto type = peek(offset).type;
            if(type==open) {
                braces++;
            } else if(type==close) {
                braces--;
                if(braces==0) return offset;
            }
        }
        return -1;
    }
}
//=========================================================================
struct Token {
    TT type;
    string value;
    int startIndex;
    int endIndex;
    int line;
    int column;
}

enum TT {
    NONE,
    IDENTIFIER,
    STRING,
    CHAR,
    NUMBER,

    LCURLY,
    RCURLY,
    LSQBRACKET,
    RSQBRACKET,
    LBRACKET,
    RBRACKET,
    LANGLE,
    RANGLE,

    LTE,
    GTE,

    SHL,
    SHR,
    USHR,

    COLON,          // :
    PLUS,           // +
    MINUS,          // -
    DIV,            // /
    ASTERISK,       // *
    PERCENT,        // %
    RT_ARROW,       // ->
    COMMA,          // ,
    SEMICOLON,      // ;
    EXCLAMATION,    // !
    AMPERSAND,      // &
    HAT,            // ^
    PIPE,           // |
    DOT,            // .
    QMARK,          // ?
    TILDE,          // ~
    HASH,           // #
    DOLLAR,         // $
    AT,             // @

    EQUALS,         // =
    ADD_ASSIGN,     // +=
    SUB_ASSIGN,     // -=
    MUL_ASSIGN,     // *=
    MOD_ASSIGN,     // %=
    DIV_ASSIGN,     // /=
    BIT_AND_ASSIGN, //  &=
    BIT_XOR_ASSIGN, // ^=
    BIT_OR_ASSIGN,  // |=
    SHL_ASSIGN,     // <<=
    SHR_ASSIGN,     // >>=
    USHR_ASSIGN,    // >>>=

    BOOL_EQ,        // ==
    BOOL_NE,        // !=
}
string toString(TT t) {
    __gshared static string[TT] map;
    if(map.length==0) with(TT) {
        map[LCURLY] = "{";
        map[RCURLY] = "}";
        map[LBRACKET] = "(";
        map[RBRACKET] = ")";
        map[LSQBRACKET] = "[";
        map[RSQBRACKET] = "]";
        map[LANGLE] = "<";
        map[RANGLE] = ">";

        map[LTE] = "<=",
        map[GTE] = ">=",

        map[SHL] = "<<",
        map[SHR] = ">>",
        map[USHR] = ">>>",

        map[EQUALS] = "=";
        map[COLON] = ":";
        map[PLUS] = "+";
        map[MINUS] = "-";
        map[DIV] = "/";
        map[ASTERISK] = "*";
        map[PERCENT] = "%";
        map[RT_ARROW] = "->";
        map[COMMA] = ",";
        map[SEMICOLON] = ";";
        map[EXCLAMATION] = "!";
        map[AMPERSAND] = "&";
        map[HAT] = "^";
        map[PIPE] = "|";
        map[DOT] = ".";
        map[QMARK] = "?";
        map[TILDE] = "~";
        map[HASH] = "#";
        map[DOLLAR] = "$";
        map[AT] = "@";

        map[ADD_ASSIGN] = "+=";
        map[SUB_ASSIGN] = "-=";
        map[MUL_ASSIGN] = "*=";
        map[MOD_ASSIGN] = "%=";
        map[DIV_ASSIGN] = "/=";
        map[BIT_AND_ASSIGN] = "&=";
        map[BIT_XOR_ASSIGN] = "^=";
        map[BIT_OR_ASSIGN] = "|=";
        map[SHL_ASSIGN] = "<<=";
        map[SHR_ASSIGN] = ">>=";
        map[USHR_ASSIGN] = ">>>=";

        map[BOOL_EQ] = "==";
        map[BOOL_NE] = "!=";
    }
    return map.get(t, "%s".format(t));
}
