module main;
/**
 *	Here is an online LLVM demo page:
 *		http://ellcc.org/?page_id=340
 */
import ppl2;
import core.memory              : GC;
import std.stdio                : writefln;
import std.array                : join;
import std.algorithm.sorting    : sort;
import std.algorithm.iteration  : map, sum;

void main(string[] argv) {

    auto mainFile = "test/./test.p2";

    auto ppl2 = PPL2.instance();

    auto b = ppl2.createProjectBuilder(mainFile);

    b.config.enableLink = true;
    b.config.writeASM   = true;
    b.config.writeOBJ   = true;
    b.config.writeAST   = true;
    b.config.writeIR    = true;

    bool success = b.build();
    if(success) {
        dumpDependencies(b);
        dumpModuleReferences(b);
        b.dumpStats();
    } else {
        auto compilerError     = cast(CompilerError)b.getException;
        auto unresolvedSymbols = cast(UnresolvedSymbols)b.getException;

        import ppl2.error;

        if(compilerError) {
            prettyErrorMsg(compilerError);
        } else if(unresolvedSymbols) {
            displayUnresolved(b.allModules);
        } else {
            writefln("%s", b.getException);
        }
    }
}
void dumpDependencies(BuildState b) {
    writefln("\nDependencies {");
    foreach (lib; b.config.libs) {
        writefln("\t%s \t %s", lib.baseModuleName, lib.absPath);
    }
    writefln("}");
}
void dumpModuleReferences(BuildState b) {
    writefln("\nModule outgoing references {");
    Module[][Module] refs;
    foreach(m; b.allModules.sort) {
        auto mods = m.getReferencedModules();
        writefln("% 25s: [%s] %s",m.canonicalName, mods.length, mods.map!(it=>it.canonicalName).join(", "));
        refs[m] = mods;

        foreach(r; mods) {
            refs.update(r, {return [m]; }, (ref Module[] it) { return it ~ m; });
        }
    }
    writefln("}\nModule incoming references {");
    foreach(m; b.allModules.sort) {
        auto v = refs[m];
        writefln("% 25s: [%s] %s",m.canonicalName, v.length, v.map!(it=>it.canonicalName).join(", "));
    }
    writefln("}");
}

