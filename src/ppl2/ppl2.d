module ppl2.ppl2;

import ppl2.internal;

final class PPL2 {
    static shared PPL2 _instance;
public:
    static auto instance() {
        auto i = cast(PPL2)atomicLoad(_instance);
        if(!i) {
            i = new PPL2;
            atomicStore(_instance, cast(shared)i);
        }
        return i;
    }
    ProjectBuilder createProjectBuilder(string mainFileRaw) {
        return new ProjectBuilder(g_llvmWrapper, new Config(mainFileRaw));
    }
    ModuleBuilder createModuleBuilder(string mainFileRaw) {
        return new ModuleBuilder(g_llvmWrapper, new Config(mainFileRaw));
    }
}
