module ppl2.build.ModuleBuilder;
///
/// Build a specified Module (including any referenced modules)
///
import ppl2.internal;

final class ModuleBuilder : BuildState {
private:
    string ir;
    string optIR;
public:
    string getUnoptimisedIR() { return ir; }
    string getOptimisedIR()   { return optIR; }

    this(LLVMWrapper llvmWrapper, Config config) {
        super(llvmWrapper, config);

        config.disableInternalLinkage = true;
    }
    bool build(Module m) {
        try{
            dd(0);
            assert(status==Status.RUNNING);
            dd(0.5);
            m.parser.parse();
            dd(1);
            resolve(m);
            dd(2);
            semanticCheck();
            dd(3);
            m.gen.generate();
            ir = m.llvmValue.dumpToString();
            optimiser.optimise(m);
            optIR = m.llvmValue.dumpToString();

            status = Status.FINISHED_OK;

            return true;
        }catch(Exception e) {
            status = Status.FINISHED_WITH_ERRORS;
        }
        return false;
    }
private:
    void resolve(Module m) {
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
    }
}