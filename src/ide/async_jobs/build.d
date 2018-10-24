module ide.async_jobs.build;

import ide.internal;
import core.sync.mutex : Mutex;
import ppl2;

final class BuildJob {
private:
    __gshared BuildJob instance;
    __gshared Mutex lock;

    string mainFileName;
    BuildIncremental builder;
public:
    this() {
        this.lock = new Mutex;
    }
    static BuildJob get() {
        lock.lock();
        scope(exit) lock.unlock();

        if(!instance) {
            instance = new BuildJob();
        }
        return instance;
    }
    void reset(string mainFileName) {

    }
    void cancel() {

    }
    Module tokenise(string canonicalName) {
        return null;
    }
    void parse(Module m) {

    }
    void resolve(Module m) {

    }
    void generateIR(Module m) {

    }
    void buildAll() {

    }
}