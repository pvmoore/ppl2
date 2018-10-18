module ppl2.ppl2;

import ppl2.internal;

final class PPL2 {
    __gshared static Module[string] modules; /// key=canonical module name
    __gshared static LLVMWrapper llvm;
    Optimiser optimiser;
    Linker linker;
public:
    __gshared static Module getModule(string canonicalName) {
        g_getModuleMutex.lock();
        scope(exit) g_getModuleMutex.unlock();

        auto m = modules.get(canonicalName, null);
        if(!m) {
            m = new Module(canonicalName, llvm);
            modules[canonicalName] = m;

            /// Get to the point where we know what the exports are
            m.parser.readContents();
            m.parser.tokenise();
        }
        return m;
    }
    __gshared static Module mainModule() {
        return modules[g_mainModuleCanonicalName];
    }

    this(string mainFileRaw) {
        try{
            StopWatch watch;
            watch.start();

            llvm      = new LLVMWrapper();
            optimiser = new Optimiser(llvm);
            linker    = new Linker(llvm);

            setConfig(new Config(mainFileRaw));

            auto mainFile = getConfig().mainFile;

            writefln("\nPPL %s", VERSION);
            writefln("Main file .... %s", getConfig().mainFile);
            writefln("Base path .... %s", getConfig().basePath);
            writefln("Target path .. %s", getConfig().targetPath);
            writefln("Target exe ... %s", getConfig().targetExe);
            writefln("");

            g_mainModuleCanonicalName = Module.getCanonicalName(mainFile);

            /// We know we need the program entry point
            functionRequired(g_mainModuleCanonicalName, "main");

            ///============================ Start
            parseAndResolve();
            removeUnreferencedNodes();
            afterResolution();
            semanticCheck();

            bool ok = false;

            if(generateIR()) {
                optimiseModules();
                combineModules();
                if(link()) {
                    ok = true;
                }
            }
            ///============================ End

            if(ok) {
                success(watch.peek().total!"nsecs");
            } else {
                failure();
            }

        }catch(CompilerError e) {
            prettyErrorMsg(e);
        }catch(UnresolvedSymbols e) {
            displayUnresolved(modules.values);
        }catch(Throwable e) {
            throw e;
        }finally{
            if(llvm) llvm.destroy();
            dumpAST();
            flushLogs();
        }
    }
private:
    void parseAndResolve() {
        int numModulesParsed = 0;
        int numUnresolvedModules = 0;
        int nodesFolded = 0;

        for(int loop=1; loop<30 && (numUnresolvedModules>0 || tasksAvailable() || nodesFolded>0 || numModulesParsed>0); loop++) {
            log("===================================================== Loop %s", loop);
            /// Process all pending tasks
            while(tasksAvailable()) {
                Task t = popTask();

                //dd(t);
                log("Executing %s (%s queued)", t, countTasks());

                Module mod = PPL2.getModule(t.moduleName);

                /// Try to parse this module if we haven't done so already
                if(!mod.isParsed) {
                    mod.parser.parse();
                }

                final switch(t.type) with(Task.Enum) {
                    case FUNC:
                        mod.resolver.resolveFunction(t.elementName);
                        break;
                    case TYPE:
                        mod.resolver.resolveAliasOrStruct(t.elementName);
                        break;
                }
            }
            log("All current tasks completed");

            numModulesParsed     = parseModules();
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
        new AfterResolution(modules.values)
            .process();
    }
    void dumpAST() {
        foreach(m; modules) {
            m.resolver.writeAST();
            writeJson(m);
        }
    }
    int parseModules() {
        int numModulesParsed = 0;
        foreach(m; modules.values) {
            if(!m.isParsed) {
                m.parser.parse();
                numModulesParsed++;
            }
        }
        return numModulesParsed;
    }
    int runResolvePass() {
        log("Running resolvers...");
        int numUnresolvedModules = 0;
        int numUnresolvedNodes   = 0;

        foreach(m; modules.values) {
            auto num = m.resolver.resolve();
            numUnresolvedNodes += num;

            if(num == 0) {
                log("\t.. %s is resolved", m.canonicalName);
            } else {
                log("\t.. %s is unresolved (%s)", m.canonicalName, num);
                numUnresolvedModules++;
            }
        }
        log("There are %s unresolved modules, %s unresolved nodes", numUnresolvedModules, numUnresolvedNodes);
        return numUnresolvedModules;
    }
    int runConstFoldPass() {
        log("Folding constants");

        int nodesFolded;

        foreach(m; modules.values) {
            nodesFolded += m.constFolder.fold();
        }
        log("Folded %s nodes", nodesFolded);
        return nodesFolded;
    }
    void removeUnreferencedNodes() {
        dd("remove unreferenced");

        log("Removing dead nodes...");
        auto removeMe = new Array!Module;
        foreach(m; modules.values) {
            if(m.numRefs==0) {
                log("\t  Removing unreferenced module %s", m.canonicalName);
                removeMe.add(m);
            }
        }
        foreach(m; removeMe) {
            modules.remove(m.canonicalName);
        }
        foreach(m; modules.values) {
            m.dce.opt();
        }
    }
    void semanticCheck() {
        log("Running semantic checks...");
        dd("semantic");
        foreach(m; modules.values) {
            m.checker.check();
        }
    }
    bool generateIR() {
        log("Generating IR");
        dd("gen IR");
        bool allOk = true;
        foreach(m; modules.values) {
            allOk &= m.gen.generate();
        }
        return allOk;
    }
    void optimiseModules() {
        dd("optimise");
        log("Optimising");
        optimiser.optimise(modules.values);
    }
    void combineModules() {
        dd("combining");
        auto mainModule   = mainModule();
        auto otherModules = modules.values
                                   .filter!(it=>it.nid != mainModule.nid)
                                   .map!(it=>it.llvmValue)
                                   .array;
        if(otherModules.length>0) {
            llvm.linkModules(mainModule.llvmValue, otherModules);
        }

        /// Run optimiser again on combined file
        optimiser.optimise(mainModule);

        writeLL(mainModule, "");
    }
    bool link() {
        dd("linking");
        log("Linking");
        return linker.link(mainModule());
    }
    void failure() {
        writefln("!! Fail !!");
    }
    void success(ulong time) {
        dumpDependencies();
        dumpModuleReferences();
        dumpStats(time);
    }
    void dumpStats(ulong time) {
        if(!getConfig().dumpStats) return;

        import core.memory : GC;

        GC.collect();

        writefln("\nOK");
        writefln("");
        writefln("Active modules ......... %s", modules.length);
        writefln("Parser time ............ %.2f ms", modules.values.map!(it=>it.parser.getElapsedNanos).sum() * 1e-6);
        writefln("Resolver time .......... %.2f ms", modules.values.map!(it=>it.resolver.getElapsedNanos).sum() * 1e-6);
        writefln("Constant folder time ... %.2f ms", modules.values.map!(it=>it.constFolder.getElapsedNanos).sum() * 1e-6);
        writefln("Semantic checker time .. %.2f ms", modules.values.map!(it=>it.checker.getElapsedNanos).sum() * 1e-6);
        writefln("IR generation time ..... %.2f ms", modules.values.map!(it=>it.gen.getElapsedNanos).sum() * 1e-6);
        writefln("Optimise time .......... %.2f ms", optimiser.getElapsedNanos * 1e-6);
        writefln("Link time .............. %.2f ms", linker.getElapsedNanos * 1e-6);
        writefln("Total time.............. %.2f ms", time * 1e-6);
        writefln("Memory used ............ %s KB", GC.stats.usedSize / 1024);
    }
    void dumpDependencies() {
        writefln("\nDependencies {");
        foreach (lib; getConfig().libs) {
            writefln("\t%s \t %s", lib.baseModuleName, lib.absPath);
        }
        writefln("}");
    }
    void dumpModuleReferences() {
        writefln("\nModule outgoing references {");
        Module[][Module] refs;
        foreach(m; modules.values.sort) {
            auto mods = m.getReferencedModules();
            writefln("% 25s: [%s] %s", m.canonicalName, mods.length, mods.map!(it=>it.canonicalName).join(", "));
            refs[m] = mods;

            foreach(r; mods) {
                refs.update(r, {return [m]; }, (ref Module[] it) { return it ~ m; });
            }
        }
        writefln("}\nModule incoming references {");
        foreach(m; modules.values.sort) {
            auto v = refs[m];
            writefln("% 25s: [%s] %s", m.canonicalName, v.length, v.map!(it=>it.canonicalName).join(", "));
        }
        writefln("}");
    }
}
