module ppl2.build.BuildIncremental;
///
/// Handle incrementally building modules.
///
import ppl2.internal;

final class BuildIncremental : BuildState {
private:

public:
    this(LLVMWrapper llvmWrapper, Config config) {
        super(llvmWrapper, config);
    }
    void parse(Module m) {
        if(status!=Status.RUNNING) throw new Error("Build has already finished");
        try{
            m.parser.parse();
        }catch(Exception e) {
            status = Status.FINISHED_WITH_ERRORS;
            throw e;
        }
    }
    void resolve(Module m) {
        if(status!=Status.RUNNING) throw new Error("Build has already finished");
        try{
            /// Get all functions in this module and make them required
            foreach(name; m.parser.publicFunctions.values) {
                functionRequired(m.canonicalName, name);
            }
            foreach(name; m.parser.privateFunctions.values) {
                functionRequired(m.canonicalName, name);
            }

            /// Ensure module is referenced
            m.numRefs++;

            writefln("requestedFunctions: %s", requestedFunction.values);
            writefln("requiredAliasOrStructs: %s", requestedAliasOrStruct.values);

            parseAndResolve();

            /// Ensure all functions are referenced
            foreach(f; m.getFunctions) {
                f.numRefs++;
            }

            removeUnreferencedNodes();
            afterResolution();
        }catch(Exception e) {
            status = Status.FINISHED_WITH_ERRORS;
            throw e;
        }
    }
    void check(Module m) {
        if(status!=Status.RUNNING) throw new Error("Build has already finished");
        try{
            semanticCheck();
        }catch(Exception e) {
            status = Status.FINISHED_WITH_ERRORS;
            throw e;
        }
    }
    void generateIR(Module m) {
        if(status!=Status.RUNNING) throw new Error("Build has already finished");
        try{
            dd("gen IR");
            m.gen.generate(false);
            dd("gen IR end");
        }catch(Exception e) {
            status = Status.FINISHED_WITH_ERRORS;
            throw e;
        }
    }
    void optimise(Module m) {
        if(status!=Status.RUNNING) throw new Error("Build has already finished");
        try{
            dd("optimise");
            optimiser.optimise(m);
            dd("optimise end");

            /// This should be the last stage
            status = Status.FINISHED_OK;
        }catch(Exception e) {
            status = Status.FINISHED_WITH_ERRORS;
            throw e;
        }
    }
    override string toString() {
        return "[BuildIncremental main:%s modules:%s]".format(config.mainFile, modules.length);
    }
}