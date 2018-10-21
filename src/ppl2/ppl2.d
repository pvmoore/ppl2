module ppl2.ppl2;

import ppl2.internal;

final class PPL2 {
    Optimiser optimiser;
    Linker linker;
public:
    __gshared PPL2 inst;
    __gshared LLVMWrapper llvmWrapper;
    Config config;

    this() {
        PPL2.inst = this;
        this.llvmWrapper = new LLVMWrapper;
        this.optimiser   = new Optimiser(llvmWrapper);
        this.linker      = new Linker(llvmWrapper);
    }
    void setProject(string mainFileRaw) {
        if(config) {
            /// Destroy previous data

        }
        this.config = new Config(mainFileRaw);
    }
    void build() {
        if(!config) {
            log("No project set");
            return;
        }
        try{
            StopWatch watch;
            watch.start();

            /// We know we need the program entry point
            functionRequired(config.mainModuleCanonicalName, "main");

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
            displayUnresolved(config.allModules);
        }catch(Throwable e) {
            throw e;
        }finally{
            dumpAST();
            flushLogs();
            if(llvmWrapper) llvmWrapper.destroy();
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

                Module mod = config.getOrCreateModule(t.moduleName);

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
        new AfterResolution(config)
            .process();
    }
    void dumpAST() {
        foreach(m; config.allModules) {
            m.resolver.writeAST();
            writeJson(m);
        }
    }
    int parseModules() {
        int numModulesParsed = 0;
        foreach(m; config.allModules) {
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

        foreach(m; config.allModules) {
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

        foreach(m; config.allModules) {
            nodesFolded += m.constFolder.fold();
        }
        log("Folded %s nodes", nodesFolded);
        return nodesFolded;
    }
    void removeUnreferencedNodes() {
        dd("remove unreferenced");

        log("Removing dead nodes...");
        auto removeMe = new Array!Module;
        foreach(m; config.allModules) {
            if(m.numRefs==0) {
                log("\t  Removing unreferenced module %s", m.canonicalName);
                removeMe.add(m);
            }
        }
        foreach(m; removeMe) {
            config.removeModule(m.canonicalName);
        }
        foreach(m; config.allModules) {
            m.dce.opt();
        }
    }
    void semanticCheck() {
        log("Running semantic checks...");
        dd("semantic");
        foreach(m; config.allModules) {
            m.checker.check();
        }
    }
    bool generateIR() {
        log("Generating IR");
        dd("gen IR");
        bool allOk = true;
        foreach(m; config.allModules) {
            allOk &= m.gen.generate();
        }
        return allOk;
    }
    void optimiseModules() {
        dd("optimise");
        log("Optimising");
        optimiser.optimise(config.allModules);
    }
    void combineModules() {
        dd("combining");
        auto mainModule   = config.mainModule;
        auto otherModules = config.allModules
                                   .filter!(it=>it.nid != mainModule.nid)
                                   .map!(it=>it.llvmValue)
                                   .array;
        if(otherModules.length>0) {
            llvmWrapper.linkModules(mainModule.llvmValue, otherModules);
        }

        /// Run optimiser again on combined file
        optimiser.optimise(mainModule);

        writeLL(mainModule, "");
    }
    bool link() {
        dd("linking");
        log("Linking");
        return linker.link(config.mainModule);
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
        if(!config.dumpStats) return;

        import core.memory : GC;

        GC.collect();

        writefln("\nOK");
        writefln("");
        writefln("Active modules ......... %s", config.allModules.length);
        writefln("Parser time ............ %.2f ms", config.allModules.map!(it=>it.parser.getElapsedNanos).sum() * 1e-6);
        writefln("Resolver time .......... %.2f ms", config.allModules.map!(it=>it.resolver.getElapsedNanos).sum() * 1e-6);
        writefln("Constant folder time ... %.2f ms", config.allModules.map!(it=>it.constFolder.getElapsedNanos).sum() * 1e-6);
        writefln("Semantic checker time .. %.2f ms", config.allModules.map!(it=>it.checker.getElapsedNanos).sum() * 1e-6);
        writefln("IR generation time ..... %.2f ms", config.allModules.map!(it=>it.gen.getElapsedNanos).sum() * 1e-6);
        writefln("Optimise time .......... %.2f ms", optimiser.getElapsedNanos * 1e-6);
        writefln("Link time .............. %.2f ms", linker.getElapsedNanos * 1e-6);
        writefln("Total time.............. %.2f ms", time * 1e-6);
        writefln("Memory used ............ %s KB", GC.stats.usedSize / 1024);
    }
    void dumpDependencies() {
        writefln("\nDependencies {");
        foreach (lib; config.libs) {
            writefln("\t%s \t %s", lib.baseModuleName, lib.absPath);
        }
        writefln("}");
    }
    void dumpModuleReferences() {
        writefln("\nModule outgoing references {");
        Module[][Module] refs;
        foreach(m; config.allModules.sort) {
            auto mods = m.getReferencedModules();
            writefln("% 25s: [%s] %s", m.canonicalName, mods.length, mods.map!(it=>it.canonicalName).join(", "));
            refs[m] = mods;

            foreach(r; mods) {
                refs.update(r, {return [m]; }, (ref Module[] it) { return it ~ m; });
            }
        }
        writefln("}\nModule incoming references {");
        foreach(m; config.allModules.sort) {
            auto v = refs[m];
            writefln("% 25s: [%s] %s", m.canonicalName, v.length, v.map!(it=>it.canonicalName).join(", "));
        }
        writefln("}");
    }
}
