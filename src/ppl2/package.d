module ppl2;

public:

import ppl2.global;
import ppl2.ppl2;
import ppl2.tokens;

import ppl2.ast.ast_node;
import ppl2.ast.module_;

import ppl2.build.ModuleBuilder;
import ppl2.build.ProjectBuilder;
import ppl2.build.BuildState;

import ppl2.config.config;
import ppl2.config.ConfigReader;

import ppl2.error.CompilationAborted;
import ppl2.error.CompileError;

import ppl2.misc.lexer;
import ppl2.misc.toml;

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

private import std.path;
private import std.file;
private import std.array : array, replace;

string normaliseDir(string path, bool makeAbsolute=false) {
    if(makeAbsolute) {
        path = asAbsolutePath(path).array;
    }
    path = asNormalizedPath(path).array;
    path = path.replace("\\", "/") ~ "/";
    return path;
}
string normaliseFile(string path,) {
    path = asNormalizedPath(path).array;
    path = path.replace("\\", "/");
    return path;
}