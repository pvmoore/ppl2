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

    writefln("");
    writefln("======================================");
    writefln("PPL %s".format(VERSION));
    writefln("======================================");

    /// Get the PPL2 singleton
    auto ppl2 = PPL2.instance();

    /// Read config file
    auto config = new ConfigReader("test/config.toml").read();

    /// Alter the configuration
    config.writeASM = true;
    config.writeOBJ = true;
    config.writeAST = true;
    config.writeIR  = true;

    writefln("\n%s", config.toString());

    /// Create a project builder
    auto builder = ppl2.createProjectBuilder(config);

    /// Build the project
    builder.build();

    /// Handle any errors
    if(builder.hasErrors()) {
        auto numErrors = builder.getErrors().length;
        writefln("\nBuild failed with %s error%s:\n", numErrors, numErrors>1?"s":"");

        if(numErrors==1) {
            writefln("%s\n", builder.getErrors()[0].toPrettyString());
        } else {
            foreach (i, err; builder.getErrors()) {
                writefln("[%s] %s", i+1, err.toConciseString());
            }
        }
    } else {
        //dumpModuleReferences(builder);
        builder.dumpStats();

        //auto refs = builder.refs();
        //auto mods = refs.allReferencedModules().map!(it=>it.canonicalName).array.sort;
        //writefln("Active modules ... %s", mods.length);
    }

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

