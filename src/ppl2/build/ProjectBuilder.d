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
    bool build() {
        startNewBuild();
        bool buildSuccessful = false;
        watch.start();
        try{
            /// We know we need the program entry point
            functionRequired(config.mainModuleCanonicalName, "main");

            ///============================ Start
            parseAndResolve();

            removeUnreferencedNodes();
            afterResolution();
            semanticCheck();

            if(generateIR()) {
                optimiseModules();
                combineModules();

                if(link()) {
                    buildSuccessful = true;
                }
            }
            ///============================ End

            status = Status.FINISHED_OK;

        }catch(Throwable e) {
            exception = e;
            status = Status.FINISHED_WITH_ERRORS;
        }finally{
            dumpAST();
            flushLogs();
            watch.stop();
        }
        return buildSuccessful;
    }
private:
    void dumpAST() {
        foreach(m; allModules) {
            m.resolver.writeAST();
        }
    }
    void optimiseModules() {
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
        if(config.enableLink) {
            dd("linking");
            log("Linking");
            return linker.link(mainModule);
        }
        return true;
    }
}