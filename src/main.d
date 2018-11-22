module main;
/**
 *	Here is an online LLVM demo page:
 *		http://ellcc.org/?page_id=340
 */
import ppl2;
import core.memory              : GC;
import std.stdio                : writefln;
import std.array                : join, array;
import std.format               : format;
import std.algorithm.sorting    : sort;
import std.algorithm.iteration  : map, sum;

void main(string[] argv) {

    auto mainFile = "test/./test.p2";

    /// Get the PPL2 singleton
    auto ppl2 = PPL2.instance();

    /// Create a project builder
    auto builder = ppl2.createProjectBuilder(new Config(mainFile));

    /// Setup the configuration
    builder.config.enableLink = true;
    builder.config.writeASM   = true;
    builder.config.writeOBJ   = true;
    builder.config.writeAST   = true;
    builder.config.writeIR    = true;
    writefln("\n%s", builder.config.toString());

    /// Build the project
    builder.build();

    /// Handle any errors
    if(builder.hasErrors()) {
        auto numErrors = builder.getErrors().length;
        writefln("Build failed with %s error%s:\n", numErrors, numErrors>1?"s":"");

        foreach(i, err; builder.getErrors()) {
            writefln("[%s] %s\n", i, err.toPrettyString());
        }
    } else {
        dumpDependencies(builder);
        dumpModuleReferences(builder);
        builder.dumpStats();

        auto refs = builder.refs();

        auto mods = refs.allReferencedModules().map!(it=>it.canonicalName).array.sort;

        writefln("%s", mods.join("\n"));
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

