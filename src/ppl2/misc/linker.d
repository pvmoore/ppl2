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

    bool link(Module m) {
        // /OPT:REF		remove unreferenced functions and data
        // /OPT:NOREF	don't remove unreferenced
        // /WX          treat linker warnings as errors
        watch.start();
        auto runtime     = dynamicRuntime;
        string targetObj = getConfig().targetPath ~ m.canonicalName ~ ".obj";
        string targetExe = getConfig().targetPath ~ getConfig().targetExe;

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

        auto pid   = spawnProcess(args);
        int status = wait(pid);

        /// Delete the obj file if required
        if(!getConfig().writeOBJ) {
            import std.file : remove;
            remove(targetObj);
        }
        watch.stop();
        return status==0;
    }
}