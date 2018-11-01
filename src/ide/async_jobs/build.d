module ide.async_jobs.build;

import ide.internal;
import core.atomic   : atomicLoad, atomicStore;
import core.thread   : Thread;
import ppl2;

final class BuildJob {
private:
    Config config;
    shared bool running;
    Thread thread;
    Exception exception;
    ProjectBuilder builder;
    void delegate(BuildJob) callback;
public:
    this(Config config, bool optimise = false) {
        this.config  = config;
        config.enableOptimisation = optimise;
    }
    bool isRunning()         { return atomicLoad(running); }
    Exception getException() { return exception; }
    BuildState getBuilder()  { return builder; }
    ulong getElapsedNanos()  { return builder.getElapsedNanos(); }

    void run(void delegate(BuildJob) callback) {
        assert(!isRunning());

        this.callback = callback;
        this.thread   = new Thread(&runAsync);

        this.thread.isDaemon = true;
        this.thread.start();
    }
private:
    void runAsync() {
        try{
            atomicStore(running,true);

            builder = PPL2.instance().createProjectBuilder(config);

            /// Disable all file writing and linking
            builder.config.enableLink = false;
            builder.config.writeASM   = false;
            builder.config.writeOBJ   = false;
            builder.config.writeAST   = false;
            builder.config.writeIR    = false;

            bool ok = builder.build();

            callback(this);

        }catch(Exception e) {
            exception = e;
        }finally{
            atomicStore(running,false);
        }
    }
}