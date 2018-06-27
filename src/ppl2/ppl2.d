module ppl2.ppl2;

import ppl2.internal;

struct ModuleMeta {
    Module module_;
    ModuleResolver resolver;
    ModuleChecker checker;
    ModuleConstantFolder constFolder;
    OptimisationDCE dce;
}

final class PPL2 {
    ModuleMeta[string] modules; /// key=canonical module name
public:
    __gshared static getModule(string canonicalName) {
        return g_allModules.get(canonicalName, null);
    }

    this(string mainFileRaw) {
        try{
            StopWatch watch;
            watch.start();

            setConfig(new Config(mainFileRaw));

            auto mainFile = getConfig().mainFile;

            writefln("\nPPL %s", VERSION);
            writefln("Options ...... %s", "");
            writefln("Main file .... %s", getConfig().mainFile);
            writefln("Base path .... %s", getConfig().basePath);
            writefln("Target path .. %s", getConfig().targetPath);
            writefln("Target exe ... %s", getConfig().targetExe);

            g_mainModuleCanonicalName = Module.getCanonicalName(mainFile);

            /// We know we need the module initialiser and the program entry point
            functionRequired(g_mainModuleCanonicalName, "new");
            functionRequired(g_mainModuleCanonicalName, "main");

            parseAndResolve();
            removeUnreferencedNodes();
            afterResolution();
            semanticCheck();

            auto time = watch.peek().total!"nsecs";

            ///========================================= end resolving

            import core.memory : GC;

            writefln("\nOk");
            writefln("Live modules ........... %s", countLiveModules());
            writefln("Modules processed ...... %s", modules.length);
            writefln("Parser time ............ %.2f ms", modules.values.map!(it=>it.module_.parser.getElapsedNanos).sum() * 1e-6);
            writefln("Resolver time .......... %.2f ms", modules.values.map!(it=>it.resolver.getElapsedNanos).sum() * 1e-6);
            writefln("Constant folder time ... %.2f ms", modules.values.map!(it=>it.constFolder.getElapsedNanos).sum() * 1e-6);
            writefln("Semantic checker time .. %.2f ms", modules.values.map!(it=>it.checker.getElapsedNanos).sum() * 1e-6);
            writefln("Total time.............. %.2f ms", time * 1e-6);
            writefln("Memory used ............ %s KB", GC.stats.usedSize / 1024);

            writefln("\nLive modules:");
            flushLogs();
            foreach(m; g_allModules) {
                writefln("- %s", m.canonicalName);
                m.dumpInfo();
            }

        }catch(CompilerError e) {
            prettyErrorMsg(e);
        }catch(UnresolvedSymbols e) {
            dd("unresolved symbols");
            displayUnresolved(modules);
        }catch(Throwable e) {
            throw e;
        }finally{
            dumpAST();
            flushLogs();
        }
    }
private:
    void parseAndResolve() {
        int numUnresolvedModules = 0;
        int nodesFolded = 0;

        for(int loop=1; loop<10 && (numUnresolvedModules>0 || tasksAvailable() || nodesFolded>0); loop++) {
            log("===================================================== Loop %s", loop);
            /// Process all pending tasks
            while(tasksAvailable()) {
                Task t = popTask();

                log("%s", t);
                //dd(t);

                ModuleMeta meta;
                Module mod;
                bool moduleCreated;
                auto p = t.moduleName in modules;
                if(p) {
                    meta = *p;
                    mod  = meta.module_;
                } else {
                    moduleCreated = true;
                    mod = Module.fromCanonicalName(t.moduleName);
                    g_allModules[t.moduleName] = mod;
                    meta = ModuleMeta(
                        mod,
                        new ModuleResolver(mod),
                        new ModuleChecker(mod),
                        new ModuleConstantFolder(mod),
                        new OptimisationDCE(mod)
                    );
                    modules[t.moduleName] = meta;
                }

                log("Executing %s (%s queued)", t, countTasks());

                if(moduleCreated) {
                    /// Get to the point where we know what the exports are
                    mod.parser.readContents();
                    mod.parser.tokenise();
                    mod.parser.extractExports();
                }

                /// Try to parse this module if we haven't done so already
                if(!mod.isParsed) {

                    mod.parser.parse();

                    if(!mod.isParsed) {
                        /// We couldn't parse the whole thing.
                        /// Push this task again for later
                        log("Re-pushing task %s", t);
                        pushTask(t);
                        continue;
                    }
                }

                final switch (t.type) with(Task.Type) {
                    case FUNC:
                        meta.resolver.resolveFunction(t.elementName);
                        break;
                    case DEFINE:
                        meta.resolver.resolveDefine(t.elementName);
                        break;
                    case EXPORTS:
                        break;
                }
            }
            log("All current tasks completed");

            numUnresolvedModules = runResolvePass();
            nodesFolded          = runConstFoldPass();
        }

        if(numUnresolvedModules > 0) {
            // todo - Collect all unresolved symbols and add them to the exception
            throw new UnresolvedSymbols();
        }
    }
    ///
    /// - Move global variable initialisation code into the module constructor new() function.
    /// - Call module new() functions at start of program entry
    ///    
    void afterResolution() {
        dd("after resolution");
        auto initFuncs = new Array!Function;

        foreach(meta; modules) {
            auto mod = meta.module_;

            /// Move global var initialisers to module new()
            auto initFunc = mod.getInitFunction();
            foreach_reverse(v; mod.getVariables()) {
                assert(v.initialiser);

                /// Arguments should always be the 1st child of body
                initFunc.getBody().insertAt(1, v.initialiser);
            }

            initFuncs.add(mod.getInitFunction());
        }

        // todo - get this in the right order
        /// Call module init functions at start of program entry
        auto mainModule = g_allModules[g_mainModuleCanonicalName];
        auto entry      = mainModule.getFunctions("main")[0];
        assert(entry);

        foreach(f; initFuncs) {
            auto call = mainModule.nodeBuilder.call("new", f);

            /// Arguments should always be the 1st child of body
            entry.getBody().insertAt(1, call);
        }
    }
    void dumpAST() {
        foreach(meta; modules) {
            meta.resolver.dumpToFile();
        }
    }
    ulong countLiveModules() {
        return g_allModules.length;
    }
    int runResolvePass() {
        log("Running resolvers...");
        int numUnresolvedModules = 0;
        int numUnresolvedNodes   = 0;

        foreach(m; modules.values) {
            auto num = m.resolver.resolve();
            numUnresolvedNodes += num;

            if(num == 0) {
                log("\t.. %s is resolved", m.module_.canonicalName);
            } else {
                log("\t.. %s is unresolved (%s)", m.module_.canonicalName, num);
                numUnresolvedModules++;
            }
        }
        log("There are %s unresolved modules, %s unresolved nodes",
            numUnresolvedModules, numUnresolvedNodes);
        return numUnresolvedModules;
    }
    int runConstFoldPass() {
        if(!getConfig().foldConstants) return 0;

        log("Folding constants");

        int nodesFolded;

        foreach(m; modules.values) {
            nodesFolded += m.constFolder.fold();
        }
        log("Folded %s nodes", nodesFolded);
        return nodesFolded;
    }
    void removeUnreferencedNodes() {
        if(!getConfig().dce) return;

        dd("remove unreferenced");

        log("Removing dead nodes...");
        auto removeMe = new Array!Module;
        foreach(m; g_allModules.values) {
            if(m.numRefs==0) {
                log("\t  Removing unreferenced module %s", m.canonicalName);
                removeMe.add(m);
            }
        }
        foreach(m; removeMe) {
            g_allModules.remove(m.canonicalName);
            modules.remove(m.canonicalName);
        }
        foreach(meta; modules.values) {
            meta.dce.opt();
        }
    }
    void semanticCheck() {
        log("Running semantic checks...");
        dd("semantic");
        foreach(m; modules.values) {
            m.checker.check();
        }
    }

}
