module ppl2.build.ProjectBuilder;
///
/// Build the entire project.
///
import ppl2.internal;

final class ProjectBuilder : BuildState {
private:
    bool buildSuccessful = false;
public:
    this(LLVMWrapper llvmWrapper, Config config) {
        super(llvmWrapper, config);
    }
    bool build() {
        startNewBuild();
        doBuild();
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

            status = Status.FINISHED_OK;

        }catch(CompilerError e) {
            status = Status.FINISHED_WITH_ERRORS;
            prettyErrorMsg(e);
        }catch(UnresolvedSymbols e) {
            status = Status.FINISHED_WITH_ERRORS;
            displayUnresolved(allModules);
        }catch(Throwable e) {
            status = Status.FINISHED_WITH_ERRORS;
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

        /// Run optimiser again on combined file
        optimiser.optimiseCombined(mainModule);

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