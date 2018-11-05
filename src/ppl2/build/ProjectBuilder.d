module ppl2.build.ProjectBuilder;
///
/// Build the entire project.
///
import ppl2.internal;

final class ProjectBuilder : BuildState {
private:

public:
    this(LLVMWrapper llvmWrapper, Config config) {
        super(llvmWrapper, config);
    }
    void build() {
        startNewBuild();
        bool buildSuccessful = false;
        watch.start();
        try{
            /// We know we need the program entry point
            functionRequired(config.mainModuleCanonicalName, "main");

            ///============================ Start
            parseAndResolve();
            if(hasErrors()) return;

            removeUnreferencedNodes();
            afterResolution();
            if(hasErrors()) return;

            semanticCheck();
            if(hasErrors()) return;

            if(generateIR()) {
                optimiseModules();

                if(config.enableLink) {
                    combineModules();

                    if(link()) {
                        /// Link succeeded
                    }
                }
            }
            ///============================ End
        }catch(CompilationAborted e) {
            writefln("Compilation aborted ... %s\n", e.reason);
        }catch(Throwable e) {
            auto m = mainModule ? mainModule : modules.values[0];
            addError(new UnknownError(m, "Unhandled exception: %s".format(e)), true);
        }finally{
            dumpAST();
            flushLogs();
            watch.stop();
        }
    }
private:
    void dumpAST() {
        foreach(m; allModules) {
            m.resolver.writeAST();
        }
    }
    void optimiseModules() {
        dd("config.enableOptimisation", config.enableOptimisation);
        if(!config.enableOptimisation) return;
        dd("optimise");
        log("Optimising");
        foreach(m; modules.values) {
            optimiser.optimise(m);
            optimisedIr[m.canonicalName] = m.llvmValue.dumpToString();
        }
    }
    void combineModules() {
        dd("combining");
        auto otherModules = allModules
                                .filter!(it=>it.nid != mainModule.nid)
                                .map!(it=>it.llvmValue)
                                .array;
        if(otherModules.length>0) {
            llvmWrapper.linkModules(mainModule.llvmValue, otherModules);
        }

        if(config.enableOptimisation) {
            /// Run optimiser again on combined file
            optimiser.optimiseCombined(mainModule);
        }

        writeLL(mainModule, "");
    }
    bool link() {
        dd("linking");
        log("Linking");
        return linker.link(mainModule);
    }
}