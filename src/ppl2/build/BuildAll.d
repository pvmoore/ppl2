module ppl2.build.BuildAll;

import ppl2.internal;

final class BuildAll : BuildState {
private:
    void delegate(BuildState) success;
    void delegate(BuildState) failure;
public:
    this(LLVMWrapper llvmWrapper, Config config) {
        super(llvmWrapper, config);
    }
    void build(void delegate(BuildState) success, void delegate(BuildState) failure) {
        this.success = success;
        this.failure = failure;
        doBuild();
    }
private:
    void doBuild() {
        watch.start();
        bool ok = false;
        try{
            /// We know we need the program entry point
            functionRequired(config.mainModuleCanonicalName, "main");

            ///============================ Start
            parseAndResolve();
            removeUnreferencedNodes();
            afterResolution();
            semanticCheck();

            if(generateIR()) {
                optimiseModules();
                combineModules();
                if(link()) {
                    ok = true;
                }
            }
            ///============================ End

        }catch(CompilerError e) {
            prettyErrorMsg(e);
        }catch(UnresolvedSymbols e) {
            displayUnresolved(allModules);
        }catch(Throwable e) {
            throw e;
        }finally{
            dumpAST();
            flushLogs();
            watch.stop();
        }

        if(ok) {
            success(this);
        } else {
            failure(this);
        }
    }
    void parseAndResolve() {
        int numModulesParsed = 0;
        int numUnresolvedModules = 0;
        int nodesFolded = 0;

        for(int loop=1;
            loop<30 && (numUnresolvedModules>0 || tasksOutstanding() || nodesFolded>0 || numModulesParsed>0);
            loop++)
        {
            log("===================================================== Loop %s", loop);
            /// Process all pending tasks
            while(tasksOutstanding()) {
                auto t = getNextTask();

                //dd(t);
                log("Executing %s (%s queued)", t, tasksRemaining());

                Module mod = getOrCreateModule(t.moduleName);

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
        new AfterResolution(this).process();
    }
    void dumpAST() {
        foreach(m; allModules) {
            m.resolver.writeAST();
            writeJson(m);
        }
    }
    int parseModules() {
        int numModulesParsed = 0;
        foreach(m; allModules) {
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

        foreach(m; allModules) {
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

        foreach(m; allModules) {
            nodesFolded += m.constFolder.fold();
        }
        log("Folded %s nodes", nodesFolded);
        return nodesFolded;
    }
    void removeUnreferencedNodes() {
        dd("remove unreferenced");

        log("Removing dead nodes...");
        auto removeMe = new Array!Module;
        foreach(m; allModules) {
            if(m.numRefs==0) {
                log("\t  Removing unreferenced module %s", m.canonicalName);
                removeMe.add(m);
            }
        }
        foreach(m; removeMe) {
            removeModule(m.canonicalName);
        }
        foreach(m; allModules) {
            m.dce.opt();
        }
    }
    void semanticCheck() {
        log("Running semantic checks...");
        dd("semantic");
        foreach(m; allModules) {
            m.checker.check();
        }
    }
    bool generateIR() {
        log("Generating IR");
        dd("gen IR");
        bool allOk = true;
        foreach(m; allModules) {
            allOk &= m.gen.generate();
        }
        return allOk;
    }
    void optimiseModules() {
        dd("optimise");
        log("Optimising");
        optimiser.optimise(allModules);
    }
    void combineModules() {
        dd("combining");
        auto otherModules = allModules
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
        return linker.link(mainModule);
    }
}