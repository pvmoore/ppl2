module ppl2.build.BuildAll;

import ppl2.internal;

final class BuildAll : BuildState {
private:
    shared bool buildStarted    = false;
    shared bool buildCompleted  = false;
    bool buildSuccessful = false;
public:
    bool running() { return atomicLoad(buildStarted) && !atomicLoad(buildCompleted); }

    this(LLVMWrapper llvmWrapper, Config config) {
        super(llvmWrapper, config);
    }
    bool build() {
        startNewBuild(true);
        buildStarted = true;
        doBuild();
        buildCompleted = true;
        return buildSuccessful;
    }

    // todo - get a list of errors
    //CompileError[] getErrors() {}
private:
    void doBuild() {
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

        }catch(CompilerError e) {
            prettyErrorMsg(e);
        }catch(UnresolvedSymbols e) {
            displayUnresolved(allModules);
        }catch(Throwable e) {
            throw e;
        }finally{
            dumpAST();
            flushLogs();
            watch.stop();
        }
    }
    void dumpAST() {
        foreach(m; allModules) {
            m.resolver.writeAST();
            writeJson(m);
        }
    }
    void optimiseModules() {
        dd("optimise");
        log("Optimising");
        optimiser.optimise(allModules);
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

        /// Run optimiser again on combined file
        optimiser.optimise(mainModule);

        writeLL(mainModule, "");
    }
    bool link() {
        dd("linking");
        log("Linking");
        return linker.link(mainModule);
    }
}