module ppl2.misc.linker;

import ppl2.internal;

final class Linker {
private:
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
        watch.start();
        string targetObj = m.config.targetPath ~ m.canonicalName ~ ".obj";
        string targetExe = m.config.targetPath ~ m.config.targetExe;

        auto config = m.config;

        writeOBJ(llvm, m);

        auto args = [
            "link",
            "/NOLOGO",
            //"/VERBOSE",
            "/MACHINE:X64",
            "/WX",              /// Treat linker warnings as errors
            "/SUBSYSTEM:console"    // todo - get the subsystem from config
        ];

        if(config.isDebug) {
            args ~= [
                "/DEBUG:NONE",  /// Don't generate a PDB for now
                "/OPT:NOREF"    /// Don't remove unreferenced functions and data
            ];
        } else {
            args ~= [
                "/RELEASE",
                "/OPT:REF",     /// Remove unreferenced functions and data
                "/LTCG",        /// Link time code gen
            ];
        }

        args ~= [
            targetObj,
            "/OUT:" ~ targetExe
        ];

        args ~= m.config.getExternalLibs();

        //dd("link command:", args);

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
            m.buildState.addError(new LinkError(m, returnStatus, errorMsg), false);
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