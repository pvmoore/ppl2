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

    buildAll(ppl2, mainFile);

    incrementalBuild(ppl2, mainFile);
}
void buildAll(PPL2 ppl2, string mainFile) {
    auto b = ppl2.prepareAFullBuild(mainFile);

    bool success = b.build();
    if(success) {
        b.dumpDependencies();
        b.dumpModuleReferences();
        b.dumpStats();
    } else {
        writefln("Fail");
    }
}
void incrementalBuild(PPL2 ppl2, string mainFile) {
    auto b = ppl2.prepareAnIncrementalBuild(mainFile);

    auto m = b.getOrCreateModule("test_access2");

    try{
        b.parse(m);
    }catch(Exception e) {
        writefln("error: %s", e);
    }

    writefln("mainModule ... %s", b.mainModule);
    writefln("allModules ... %s", b.allModules);
    writefln("");

    writefln("canonicalName........ %s", m.canonicalName);
    writefln("fileName ............ %s", m.fileName);
    writefln("isParsed ............ %s", m.isParsed);
    writefln("isMainModule ........ %s", m.isMainModule);
    writefln("publicTypes ......... %s", m.parser.publicTypes.values);
    writefln("publicFunctions ..... %s", m.parser.publicFunctions.values);
    writefln("privateFunctions .... %s", m.parser.privateFunctions.values);
    writefln("tokens .............. %s", m.parser.getInitialTokens().length);


}
