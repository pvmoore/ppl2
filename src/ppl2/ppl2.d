module ppl2.ppl2;

import ppl2.internal;

final class PPL2 {
    BuildAll buildAll;
    BuildIncremental buildIncremental;
    Mutex lock;
    static shared PPL2 _instance;

    this() {
        this.lock = new Mutex;
    }
public:
    static auto instance() {
        auto i = cast(PPL2)atomicLoad(_instance);
        if(!i) {
            i = new PPL2;
            _instance = cast(shared)i;
        }
        return i;
    }
    BuildAll prepareAFullBuild(string mainFileRaw, bool discardPrevious = false) {
        lock.lock();
        scope(exit) lock.unlock();

        if(!buildAll) {
            buildAll = new BuildAll(g_llvmWrapper, new Config(mainFileRaw));
        } else if(!discardPrevious) {

        }
        return buildAll;
    }
    BuildIncremental prepareAnIncrementalBuild(string mainFileRaw, bool discardPrevious = false) {
        lock.lock();
        scope(exit) lock.unlock();

        if(!buildIncremental) {
            buildIncremental = new BuildIncremental(g_llvmWrapper, new Config(mainFileRaw));
        } else if(!discardPrevious) {

        }
        return buildIncremental;
    }
}
