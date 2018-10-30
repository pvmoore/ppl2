module ide.async_jobs.build;

import ide.internal;
import core.atomic   : atomicLoad, atomicStore;
import core.thread   : Thread;
import ppl2;

final class BuildJob {
private:
    string mainFileName;
    shared bool running;
    Thread thread;
    Exception exception;
    ProjectBuilder build;
public:
    this(string mainFileName) {
        this.mainFileName = mainFileName;
    }
    bool isRunning()         { return atomicLoad(running); }
    Exception getException() { return exception; }
    BuildState getBuild()    { return build; }

    void run() {
        assert(!isRunning());

        this.thread = new Thread(&runAsync);
        this.thread.isDaemon = true;
        this.thread.start();
    }
private:
    void runAsync() {
        try{
            atomicStore(running,true);
            build = PPL2.instance().createProjectBuilder(mainFileName);

            /// Disable all file writing and linking
            build.config.enableLink = false;
            build.config.writeASM   = false;
            build.config.writeOBJ   = false;
            build.config.writeAST   = false;
            build.config.writeIR    = false;

            bool ok = build.build();

        }catch(Exception e) {
            exception = e;
        }finally{
            atomicStore(running,false);
        }
    }
}