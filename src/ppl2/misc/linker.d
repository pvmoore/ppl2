module ppl2.misc.linker;

import ppl2.internal;

final class Linker {
private:
    const string[] dynamicRuntime = [
        "msvcrt.lib",
        "ucrt.lib",
        "vcruntime.lib"];
    const string[] staticRuntime = [
        "libcmt.lib",
        "libucrt.lib",
        "libvcruntime.lib"
    ];
    LLVMWrapper llvm;
    StopWatch watch;
public:
    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    this(LLVMWrapper llvm) {
        this.llvm = llvm;
    }
    void clearState() {
        watch.reset();
    }

    bool link(Module m) {
        // /OPT:REF		remove unreferenced functions and data
        // /OPT:NOREF	don't remove unreferenced
        // /WX          treat linker warnings as errors
        watch.start();
        auto runtime     = dynamicRuntime;
        string targetObj = m.config.targetPath ~ m.canonicalName ~ ".obj";
        string targetExe = m.config.targetPath ~ m.config.targetExe;

        writeASM(llvm, m);
        writeOBJ(llvm, m);

        auto args = [
            "link",
            "/NOLOGO",
            //"/VERBOSE",
            "/MACHINE:X64",
            "/OPT:REF",
            "/WX",
            "/SUBSYSTEM:console",
            targetObj,
            "/OUT:" ~ targetExe
        ] ~ runtime;

        import std.process : spawnProcess, wait;

        int returnStatus;
        string errorMsg;
        try{
            auto pid = spawnProcess(args);
            returnStatus = wait(pid);
        }catch(Exception e) {
            errorMsg     = e.msg;
            returnStatus = -1;
        }

        if(returnStatus!=0) {
            m.buildState.addError(new LinkError(returnStatus, errorMsg), false);
        }

        /// Delete the obj file if required
        if(!m.config.writeOBJ) {
            import std.file : remove;
            remove(targetObj);
        }
        watch.stop();
        return returnStatus==0;
    }
}