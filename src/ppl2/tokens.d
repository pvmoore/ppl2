module ppl2.tokens;

import ppl2.internal;

final class Tokens {
private:
    Token[] tokens;
    int pos = 0;
    Stack!int marks;
    Stack!Access _access;
public:
    Module module_;

    this(Module module_, Token[] tokens) {
        this.module_  = module_;
        this.tokens   = tokens;
        this.marks    = new Stack!int;
        this._access  = new Stack!Access;
        reset();
    }
    auto reuse(Module module_, Token[] tokens) {
        this.module_ = module_;
        this.tokens  = tokens;
        return reset();
    }
    auto reset() {
        this.pos = 0;
        this.marks.clear();
        this._access.clear();
        this._access.push(Access.PRIVATE);
        return this;
    }
    void setLength(int len) {
        if(tokens.length > len) {
            tokens.length = len;
        }
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
    Access access() { return _access.peek(); }
    void setAccess(Access a) {
        _access.pop();
        _access.push(a);
    }
    /// Start of Module level NamedStruct
    void startAccessScope() {
        _access.push(Access.PRIVATE);
        assert(_access.length==2);
    }
    /// End of Module level NamedStruct
    void endAccessScope() {
        _access.pop();
        assert(_access.length==1);
    }
    //=======================================
    int index()    { return pos; }
    int line()     { return get().line; }
    int column()   { return get().column; }
    TT type()      { return get().type; }
    string value() { return get().value; }

    Token get() {
        if(pos >= tokens.length) return NO_TOKEN;
        return tokens[pos];
    }
    Token[] opSlice() {
        return tokens;
    }
	Token[] opSlice(ulong from, ulong to) {
        return tokens[from..to];
    }
    Token peek(int offset) {
        if(pos+offset < 0 || pos+offset >= tokens.length) return NO_TOKEN;
        return tokens[pos+offset];
    }
    int length() { return tokens.length.as!int; }
    bool isKeyword(string k) {
        return type()==TT.IDENTIFIER && value()==k;
    }
    bool onSameLine(int offset = 0) {
        return peek(offset).line==peek(offset-1).line;
    }
    //=======================================
    void next(int numToMove=1) {
        pos += numToMove;
    }
    void prev(int numToMove=1) {
        pos -= numToMove;
    }
    void skip(TT t) {
        if(type()!=t) module_.addError(this, "Expecting %s".format(t), false);
        next();
    }
    void skip(string kw) {
        if(value()!=kw) module_.addError(this, "Expecting %s".format(kw), false);
        next();
    }
    bool typeIn(TT[] types...) {
        auto ty = type();
        foreach(t; types) if(t==ty) return true;
        return false;
    }
    void expect(TT[] types...) {
        foreach(t; types) if(type()==t) return;
        module_.addError(this, "Expecting one of %s".format(types.toString()), false);
    }
    void dontExpect(TT[] types...) {
        foreach(t; types) if(type()==t) {
            module_.addError(this, "Not expecting %s".format(t), false);
        }
    }
    bool hasNext() {
        return pos < tokens.length;
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
    int findInScope(TT t, int offset=0) {
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
    bool scopeContains(TT t) {
        return findInScope(t) !=-1;
    }
    ///
    /// Returns the offset of the closing bracket.
    /// Assumes we are currently at the opening bracket or before it.
    /// Returns -1 if the end bracket is not found.
    ///
    int findEndOfBlock(TT brtype, int startOffset=0) {
        auto open  = brtype;
        auto close = open==TT.LBRACKET   ? TT.RBRACKET   :
                     open==TT.LSQBRACKET ? TT.RSQBRACKET :
                     open==TT.LCURLY     ? TT.RCURLY     :
                     open==TT.LANGLE     ? TT.RANGLE     : TT.NONE;
        assert(close!=TT.NONE);
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
    int length;
    int line;
    int column;
    Type templateType;

    string toString() {
        string t  = type==TT.IDENTIFIER ? "'"~value~"'" : "%s".format(type);
        string tt = templateType ? " (%s)".format(templateType) : "";
        return "%s Len:%s L:%s C:%s%s".format(t, length, line, column, tt);
    }
}
Token copy(Token t, string value) {
    t.type  = TT.IDENTIFIER;
    t.value = value;
    return t;
}
Token copy(Token t, TT e) {
    t.type  = e;
    t.value = "";
    return t;
}
Token copy(Token t, string value, Type templateType) {
    t.type         = TT.IDENTIFIER;
    t.value        = value;
    t.templateType = templateType;
    return t;
}
string toSimpleString(Token t) {
    return t.type==TT.IDENTIFIER ? t.value  :
           t.type==TT.NUMBER ? t.value      : t.type.toString;
}
string toSimpleString(Token[] tokens) {
    auto buf = new StringBuffer;
    foreach(i, t; tokens) {
        if(i>0) buf.add(" ");
        buf.add(toSimpleString(t));
    }
    return buf.toString();
}
string toString(TT[] tt) {
    auto buf = new StringBuffer;
    foreach(i, t; tt) {
        if(i>0) buf.add(" ");
        buf.add(toString(t));
    }
    return buf.toString();
}

enum TT {
    NONE,
    IDENTIFIER,
    STRING,
    CHAR,
    NUMBER,
    LINE_COMMENT,
    MULTILINE_COMMENT,

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
    DBL_COLON,      // ::
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
    COMPARE,        // <>
}
bool isComment(TT t) {
    return t==TT.LINE_COMMENT || t==TT.MULTILINE_COMMENT;
}
bool isString(TT t) {
    return t==TT.STRING;
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
        map[DBL_COLON] = "::";
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
        map[COMPARE] = "<>";
    }
    return map.get(t, "%s".format(t));
}
