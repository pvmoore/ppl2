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
        bool astDumped;
        try{
            /// We know we need the program entry point
            functionRequired(config.mainModuleCanonicalName, "main");

            ///============================ Start
            parseAndResolve();
            if(hasErrors()) return;

            refInfo.process();

            removeUnreferencedNodes();
            afterResolution();
            if(hasErrors()) return;

            semanticCheck();
            if(hasErrors()) return;

            dumpAST();
            astDumped = true;

            if(generateIR()) {
                optimiseModules();

                combineModules();

                if(config.enableLink) {
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
            if(!astDumped) dumpAST();
            flushLogs();
            watch.stop();
        }
    }
private:
    void dumpAST() {
        dd("dumpAST");
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
            if(config.collectOutput) {
                optimisedIr[m.canonicalName] = m.llvmValue.dumpToString();
            }
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
        if(config.collectOutput) {
            linkedIr  = mainModule.llvmValue.dumpToString();
            linkedASM = llvmWrapper.x86Target.writeToStringASM(mainModule.llvmValue);
        }

        writeLL(mainModule, "");
        writeASM(llvmWrapper, mainModule);
    }
    bool link() {
        dd("linking");
        log("Linking");
        return linker.link(mainModule);
    }
}