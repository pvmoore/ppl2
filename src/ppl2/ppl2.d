module ppl2.ppl2;

import ppl2.internal;

final class PPL2 {
    LLVMWrapper llvmWrapper;
    Config config;
public:
    __gshared PPL2 inst;

    this() {
        PPL2.inst = this;
        this.llvmWrapper = new LLVMWrapper;
    }
    void destroy() {
        if(llvmWrapper) llvmWrapper.destroy();
    }
    Config getConfig() {
        return config;
    }
    void setProject(string mainFileRaw) {
        if(config) {
            assert(false, "todo - remove previous data");
        }
        this.config = new Config(mainFileRaw);
    }
    void build() {
        if(!config) {
            log("No project set");
            return;
        }

        auto buildAll = new BuildAll(llvmWrapper, config);

        buildAll.build(&success, &failure);
    }
private:
    void failure(BuildState state) {
        writefln("!! Fail !!");
    }
    void success(BuildState state) {
        dumpDependencies(state);
        dumpModuleReferences(state);
        dumpStats(state);
    }
    void dumpStats(BuildState state) {
        if(!config.dumpStats) return;

        import core.memory : GC;

        GC.collect();

        writefln("\nOK");
        writefln("");
        writefln("Active modules ......... %s", state.allModules.length);
        writefln("Parser time ............ %.2f ms", state.allModules.map!(it=>it.parser.getElapsedNanos).sum() * 1e-6);
        writefln("Resolver time .......... %.2f ms", state.allModules.map!(it=>it.resolver.getElapsedNanos).sum() * 1e-6);
        writefln("Constant folder time ... %.2f ms", state.allModules.map!(it=>it.constFolder.getElapsedNanos).sum() * 1e-6);
        writefln("Semantic checker time .. %.2f ms", state.allModules.map!(it=>it.checker.getElapsedNanos).sum() * 1e-6);
        writefln("IR generation time ..... %.2f ms", state.allModules.map!(it=>it.gen.getElapsedNanos).sum() * 1e-6);
        writefln("Optimiser time ......... %.2f ms", state.optimiser.getElapsedNanos * 1e-6);
        writefln("Linker time ............ %.2f ms", state.linker.getElapsedNanos * 1e-6);
        writefln("Total time.............. %.2f ms", state.getElapsedNanos * 1e-6);
        writefln("Memory used ............ %.2f MB", GC.stats.usedSize / (1024*1024.0));
    }
    void dumpDependencies(BuildState state) {
        writefln("\nDependencies {");
        foreach (lib; config.libs) {
            writefln("\t%s \t %s", lib.baseModuleName, lib.absPath);
        }
        writefln("}");
    }
    void dumpModuleReferences(BuildState state) {
        writefln("\nModule outgoing references {");
        Module[][Module] refs;
        foreach(m; state.allModules.sort) {
            auto mods = m.getReferencedModules();
            writefln("% 25s: [%s] %s", m.canonicalName, mods.length, mods.map!(it=>it.canonicalName).join(", "));
            refs[m] = mods;

            foreach(r; mods) {
                refs.update(r, {return [m]; }, (ref Module[] it) { return it ~ m; });
            }
        }
        writefln("}\nModule incoming references {");
        foreach(m; state.allModules.sort) {
            auto v = refs[m];
            writefln("% 25s: [%s] %s", m.canonicalName, v.length, v.map!(it=>it.canonicalName).join(", "));
        }
        writefln("}");
    }
}
