module ide.async_jobs.build;

import ide.internal;
import core.sync.mutex : Mutex;
import ppl2;

final class BuildJob {
private:
    __gshared BuildJob instance;
    __gshared Mutex lock;

    string mainFileName;
    string moduleCanonicalName;

    BuildIncremental build;
    PPL2 ppl2;
public:
    this() {
        this.lock = new Mutex;
        this.ppl2 = PPL2.instance();
    }
    static BuildJob get() {
        lock.lock();
        scope(exit) lock.unlock();

        if(!instance) {
            instance = new BuildJob();
        }
        return instance;
    }
    auto setMainFile(string mainFile) {
        this.mainFileName = mainFile;
        return this;
    }
    auto setModule(string canonicalName) {
        this.moduleCanonicalName = canonicalName;
        return this;
    }
    /// Job method run asynchronously
    void run() {
        assert(mainFileName);
        assert(moduleCanonicalName);

        auto build = ppl2.prepareAnIncrementalBuild(mainFileName);

        auto m = build.getOrCreateModule(moduleCanonicalName);

        try{
            build.parse(m);
        }catch(Exception e) {
            writefln("error: %s", e);
        }
    }


    void cancel() {

    }
    //Module tokenise(string canonicalName) {
    //    return null;
    //}
    //void parse(Module m) {
    //
    //}
    //void resolve(Module m) {
    //
    //}
    //void generateIR(Module m) {
    //
    //}
    //void buildAll() {
    //
    //}
}