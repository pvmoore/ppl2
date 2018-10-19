module ppl2;

public:

import ppl2.global;
import ppl2.tokens;

import ppl2.misc.lexer;

T min(T)(T a, T b) {
    return a < b ? a : b;
}
T max(T)(T a, T b) {
    return a > b ? a: b;
}

// Debug logging
void dd(A...)(A args) {
    import std.stdio : writef, writefln;
    import common : flushConsole;

    foreach(a; args) {
        writef("%s ", a);
    }
    writefln("");
    flushConsole();
}
string convertTabsToSpaces(string s, int tabsize=4) {
    import std.string : indexOf;
    import std.array  : appender;
    import common : repeat;

    if(s.indexOf("\t")==-1) return s;
    auto buf = appender!(string);
    auto spaces = " ".repeat(tabsize);
    foreach(ch; s) {
        if(ch=='\t') buf ~= spaces;
        else buf ~= ch;
    }
    return buf.data;
}