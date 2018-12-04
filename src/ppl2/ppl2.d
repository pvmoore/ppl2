module ppl2.ppl2;

import ppl2.internal;

final class PPL2 {
    static shared PPL2 _instance;
    this() {}
public:
    static auto instance() {
        auto i = cast(PPL2)atomicLoad(_instance);
        if(!i) {
            i = new PPL2;
            atomicStore(_instance, cast(shared)i);
        }
        return i;
    }
    ProjectBuilder createProjectBuilder(Config config) {
        return new ProjectBuilder(g_llvmWrapper, config);
    }
    //ModuleBuilder createModuleBuilder(Config config) {
    //    return new ModuleBuilder(g_llvmWrapper, config);
    //}
}
