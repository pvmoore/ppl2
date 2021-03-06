module ppl2.build.BuildState;

import ppl2.internal;

abstract class BuildState {
protected:
    Mutex getModuleLock;

    Queue!Task taskQueue;
    Set!string requestedAliasOrStruct;    /// moduleName|defineName
    Set!string requestedFunction;         /// moduleName|funcName

    Module[/*canonicalName*/string] modules;
    string[string] unoptimisedIr;
    string[string] optimisedIr;
    string linkedIr;
    string linkedASM;

    StopWatch watch;

    CompileError[string] errors;
    //ReferenceInformation refInfo;
public:
    struct Task {
        enum Enum { FUNC, TYPE }
        Enum type;

        string moduleName;
        string elementName;
    }
    LLVMWrapper llvmWrapper;
    Optimiser optimiser;
    Linker linker;
    Config config;
    Module mainModule;
    Mangler mangler;

    ulong getElapsedNanos() const { return watch.peek().total!"nsecs"; }
    bool hasErrors() const        { return errors.length>0; }
    //auto refs()                   { return refInfo; }

    CompileError[] getErrors() {
        import std.algorithm.comparison : cmp;
        alias comp = (x,y) {
            int r = cmp(x.module_.canonicalName, y.module_.canonicalName);
            if(r!=0) return r < 0;
            return x.line*1_000_000 + x.column < y.line*1_000_000 + y.column;
        };
        return errors.values.sort!(comp).array;
    }

    string getOptimisedIR(string canonicalName)   { return optimisedIr.get(canonicalName, null); }
    string getUnoptimisedIR(string canonicalName) { return unoptimisedIr.get(canonicalName, null); }
    string getLinkedIR()                          { return linkedIr; }
    string getLinkedASM()                         { return linkedASM; }

    this(LLVMWrapper llvmWrapper, Config config) {
        this.llvmWrapper            = llvmWrapper;
        this.optimiser              = new Optimiser(llvmWrapper);
        this.linker                 = new Linker(llvmWrapper);
        this.config                 = config;
        this.getModuleLock          = new Mutex;
        this.taskQueue              = new Queue!Task(1024);
        this.requestedAliasOrStruct = new Set!string;
        this.requestedFunction      = new Set!string;
        this.mangler                = new Mangler;
        //this.refInfo                = new ReferenceInformation(this);
    }
    /// Tasks
    bool tasksOutstanding()       { return !taskQueue.empty; }
    int tasksRemaining()          { return taskQueue.length; }
    Task getNextTask()            { return taskQueue.pop; }
    void addTask(Task t)          { taskQueue.push(t); }

    void addError(CompileError e, bool canContinue) {
        string key = e.getKey();
        if(key in errors) return;

        errors[key] = e;

        if(!canContinue) {
            throw new CompilationAborted(CompilationAborted.Reason.COULD_NOT_CONTINUE);
        }
        if(errors.length >= config.maxErrors) {
            throw new CompilationAborted(CompilationAborted.Reason.MAX_ERRORS_REACHED);
        }
    }
    void startNewBuild() {
        requestedAliasOrStruct.clear();
        requestedFunction.clear();
        taskQueue.clear();
        optimiser.clearState();
        linker.clearState();
        mangler.clearState();
        unoptimisedIr.clear();
        optimisedIr.clear();
        errors.clear();

        foreach(m; modules.values) {
            if(m.llvmValue) m.llvmValue.destroy();
        }
        modules.clear();
    }

    /// Modules
    Module getModule(string canonicalName) {
        getModuleLock.lock();
        scope(exit) getModuleLock.unlock();

        return modules.get(canonicalName, null);
    }
    Module getOrCreateModule(string canonicalName, string newSource) {
        auto src = convertTabsToSpaces(newSource);

        getModuleLock.lock();
        scope(exit) getModuleLock.unlock();

        auto m = modules.get(canonicalName, null);
        assert(!m);

        //if(m) {
        //    /// Check the src hash
        //    auto hash = Hasher.sha1(src);
        //    if (hash==m.parser.getSourceTextHash()) {
        //        /// Source has not changed.
        //        return m;
        //    }
        //
        //    /// The module and all modules that reference it are now stale
        //    clearState(m, new Set!string);
        //
        //    m.parser.setSourceText(src);
        //
        //} else {
            m = createModule(canonicalName, true, src);
        //}
        return m;
    }
    Module getOrCreateModule(string canonicalName) {
        getModuleLock.lock();
        scope(exit) getModuleLock.unlock();

        auto m = modules.get(canonicalName, null);
        if(!m) {
            m = createModule(canonicalName);
        }
        return m;
    }
    void removeModule(string canonicalName) {
        getModuleLock.lock();
        scope(exit) getModuleLock.unlock();

        modules.remove(canonicalName);
    }
    Module[] allModules() {
        return modules.values;
    }
    Module[] allModulesThatReference(Module m) {
        Module[] refs;
        refs.reserve(20);

        foreach(mod; allModules) {
            foreach(r; mod.getReferencedModules()) {
                if(r==m) refs ~= r;
            }
        }
        return refs;
    }
    ///
    /// Recursively clear module state so that it can be re-used
    ///
    void clearState(Module m, Set!string hasBeenReset) {
        if(hasBeenReset.contains(m.canonicalName)) return;
        hasBeenReset.add(m.canonicalName);
        writefln("clearState(%s)", m.canonicalName);

        m.clearState();

        Module[] refs = allModulesThatReference(m);
        writefln("\tModules referencing %s : %s", m.canonicalName, refs);
        foreach(r; refs) {
            clearState(r, hasBeenReset);
        }
    }

    /// Symbols
    void aliasEnumOrStructRequired(string moduleName, string defineName) {
        string key = "%s|%s".format(moduleName, defineName);

        if(requestedAliasOrStruct.contains(key)) return;
        requestedAliasOrStruct.add(key);

        Task t = {
            Task.Enum.TYPE,
            moduleName,
            defineName
        };
        taskQueue.push(t);
    }
    void functionRequired(string moduleName, string funcName) {
        string key = "%s|%s".format(moduleName, funcName);

        if(requestedFunction.contains(key)) return;
        requestedFunction.add(key);

        Task t = {
            Task.Enum.FUNC,
            moduleName,
            funcName
        };
        taskQueue.push(t);
    }

    /// Stats
    void dumpStats(void delegate(string) receiver = null) {
        if(!receiver) receiver = it=>writeln(it);

        GC.collect();

        receiver("\nOK");
        receiver("");
        receiver("Active modules ......... %s".format(allModules.length));
        receiver("Parser time ............ %.2f ms".format(allModules.map!(it=>it.parser.getElapsedNanos).sum() * 1e-6));
        receiver("Resolver time .......... %.2f ms".format(allModules.map!(it=>it.resolver.getElapsedNanos).sum() * 1e-6));
        receiver("DCE time ............... %.2f ms".format(allModules.map!(it=>it.dce.getElapsedNanos).sum() * 1e-6));
        receiver("Semantic checker time .. %.2f ms".format(allModules.map!(it=>it.checker.getElapsedNanos).sum() * 1e-6));
        receiver("IR generation time ..... %.2f ms".format(allModules.map!(it=>it.gen.getElapsedNanos).sum() * 1e-6));
        receiver("Optimiser time ......... %.2f ms".format(optimiser.getElapsedNanos * 1e-6));
        receiver("Linker time ............ %.2f ms".format(linker.getElapsedNanos * 1e-6));
        receiver("Total time.............. %.2f ms".format(getElapsedNanos * 1e-6));
        receiver("Memory used ............ %.2f MB".format(GC.stats.usedSize / (1024*1024.0)));
    }
private:
    Module createModule(string canonicalName, bool withSrc = false, string src = null) {
        auto m = new Module(canonicalName, llvmWrapper, this);
        modules[canonicalName] = m;

        mangler.addUniqueModuleName(canonicalName);

        if(canonicalName==config.getMainModuleCanonicalName) {
            m.isMainModule = true;
            mainModule     = m;
        }

        /// Read, tokenise and extract public types and functions
        if(withSrc) {
            m.parser.setSourceText(src);
        } else {
            m.parser.readSourceFromDisk();
        }

        return m;
    }
protected:
    void parseAndResolve() {
        dd("parseAndResolve");

        auto prevUnresolved = new Set!int;
        bool stalemate      = false;

        for(int loop=1; loop<30; loop++) {
            log("===================================================== Loop %s", loop);

            /// Process all pending tasks
            while(tasksOutstanding()) {
                auto t = getNextTask();

                //dd(t);
                log("Executing %s (%s queued)", t, tasksRemaining());

                Module mod = getOrCreateModule(t.moduleName);

                /// Parse this module if we haven't done so already
                if(!mod.isParsed) {
                    mod.parser.parse();
                }

                final switch(t.type) with(Task.Enum) {
                    case FUNC:
                        mod.resolver.resolveFunction(t.elementName);
                        break;
                    case TYPE:
                        mod.resolver.resolveAliasEnumOrStruct(t.elementName);
                        break;
                }
            }
            log("All current tasks completed");

            bool nodesModified = false;
            auto unresolved    = new Set!int;

            parseModules();
            runResolvePass(unresolved, nodesModified, stalemate);

            if(unresolved.length==0 && !tasksOutstanding() && !nodesModified) return;

            if(!nodesModified && unresolved==prevUnresolved) {
                if(stalemate) {
                    log("Couldn't make any further progress");
                    break;
                }
                stalemate = true;
            } else {
                stalemate = false;
            }

            prevUnresolved = unresolved;
        }
        /// If we get here we couldn't resolve something
        if(!hasErrors()) {
            convertUnresolvedNodesIntoErrors();
        }
    }
    void parseModules() {
        log("parseModules");
        foreach(m; allModules) {
            if(!m.isParsed) {
                m.parser.parse();
            }
        }
    }
    void runResolvePass(Set!int unresolved, ref bool nodesModified, bool resolveStalemate) {
        log("Running resolvers...");
        assert(nodesModified==false);
        assert(unresolved.length==0);

        int numUnresolvedModules = 0;

        foreach(m; allModules) {
            bool resolved  = m.resolver.resolve(resolveStalemate);
            nodesModified |= m.resolver.isModified();

            unresolved.add(
                m.resolver.getUnresolvedNodes().map!(it=>it.nid).array
            );

            if(resolved) {
                log("\t.. %s is resolved", m.canonicalName);
            } else {
                log("\t.. %s is unresolved", m.canonicalName);
                numUnresolvedModules++;
            }
        }
        log("There are %s unresolved modules, %s unresolved nodes", numUnresolvedModules, unresolved.length);
    }
    void removeUnreferencedNodes() {
        dd("remove unreferenced");

        log("Removing dead nodes...");
        auto removeMe = new DynamicArray!Module;
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
    ///
    /// - Move global variable initialisation code into the module constructor new() function.
    /// - Call module new() functions at start of program entry
    ///
    void afterResolution() {
        dd("after resolution");
        new AfterResolution(this).process(modules.values);
    }
    void semanticCheck() {
        log("Running semantic checks...");
        dd("semantic");
        foreach(m; allModules) {
            m.checker.check();
        }
        dd("semantic end");
    }
    bool generateIR() {
        log("Generating IR");
        bool allOk = true;
        foreach(m; allModules) {
            allOk &= m.gen.generate();

            if(config.collectOutput) {
                unoptimisedIr[m.canonicalName] = m.llvmValue.dumpToString();
            }
        }
        return allOk;
    }
    void convertUnresolvedNodesIntoErrors() {
        foreach(m; modules.values) {
            foreach(n; m.resolver.getUnresolvedNodes()) with(NodeID) {

                if(n.id==IDENTIFIER) {
                    auto identifier = n.as!Identifier;
                    m.addError(n, "Unresolved identifier %s".format(identifier.name), true);
                } else if(n.id==VARIABLE) {
                    auto variable = n.as!Variable;
                    m.addError(n, "Unresolved variable %s".format(variable.name), true);
                } else {
                    writefln("\t%s[line %s] %s: %s", m.canonicalName, n.line+1, n.id, n);
                }
            }
        }
        if(!hasErrors()) {
            auto m = mainModule ? mainModule : modules.values[0];
            addError(new UnknownError(m, "There were unresolved symbols but no errors were added"), true);
        }
    }
}