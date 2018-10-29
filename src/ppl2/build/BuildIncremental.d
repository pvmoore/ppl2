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
        m.parser.parse();
    }
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
    void check(Module m) {
        semanticCheck();
    }
    void generateIR(Module m) {
        m.gen.generate(false);
    }
    void optimise(Module m) {
        optimiser.optimise(m);
    }
    override string toString() {
        return "[BuildIncremental main:%s modules:%s]".format(config.mainFile, modules.length);
    }
}