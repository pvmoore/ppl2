module ppl2;

public:

import ppl2.config;
import ppl2.global;
import ppl2.ppl2;
import ppl2.tokens;

import ppl2.ast.ast_node;
import ppl2.ast.module_;

import ppl2.build.ModuleBuilder;
import ppl2.build.ProjectBuilder;
import ppl2.build.BuildState;

import ppl2.error : AmbiguousCall, CompilerError, UnresolvedSymbols;

import ppl2.misc.lexer;

import ppl2.type.type;


T min(T)(T a, T b) {
    return a < b ? a : b;
}
T max(T)(T a, T b) {
    return a > b ? a: b;
}

/// Debug logging
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