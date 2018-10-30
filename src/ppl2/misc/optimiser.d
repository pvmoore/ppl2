module ppl2.misc.optimiser;

import ppl2.internal;

final class Optimiser {
private:
    LLVMWrapper llvm;
    LLVMPassManager passManager;
    StopWatch watch;
public:
    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    this(LLVMWrapper llvm) {
        this.llvm        = llvm;
        this.passManager = llvm.passManager;
        passManager.addPasses();
    }
    void clearState() {
        watch.reset();
    }
    void optimise(Module[] modules) {
        watch.start();
        foreach(m; modules) {
            passManager.runOnModule(m.llvmValue);
            writeLL(m, "ir_opt/");
        }
        watch.stop();
    }
    void optimise(Module m) {
        watch.start();
        passManager.runOnModule(m.llvmValue);
        writeLL(m, "");
        watch.stop();
    }
}