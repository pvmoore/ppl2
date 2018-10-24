module ppl2.build.BuildState;

import ppl2.internal;

class BuildState {
private:
    Queue!Task taskQueue;
    Set!string requestedAliasOrStruct;    /// moduleName|defineName
    Set!string requestedFunction;         /// moduleName|funcName

    Module[/*canonicalName*/string] modules;
    Mutex lock;
protected:
    StopWatch watch;
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

    this(LLVMWrapper llvmWrapper, Config config) {
        this.llvmWrapper            = llvmWrapper;
        this.optimiser              = new Optimiser(llvmWrapper);
        this.linker                 = new Linker(llvmWrapper);
        this.config                 = config;
        this.lock                   = new Mutex;
        this.taskQueue              = new Queue!Task(1024);
        this.requestedAliasOrStruct = new Set!string;
        this.requestedFunction      = new Set!string;
        this.mangler                = new Mangler;
    }
    bool tasksOutstanding() { return !taskQueue.empty; }
    int tasksRemaining()    { return taskQueue.length; }
    Task getNextTask()      { return taskQueue.pop; }
    void addTask(Task t)    { taskQueue.push(t); }

    void aliasOrStructRequired(string moduleName, string defineName) {
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
    Module getOrCreateModule(string canonicalName) {
        lock.lock();
        scope(exit) lock.unlock();

        auto m = modules.get(canonicalName, null);
        if(!m) {
            m = new Module(canonicalName, llvmWrapper, this);
            modules[canonicalName] = m;

            mangler.addUniqueModuleName(canonicalName);

            if(canonicalName==config.mainModuleCanonicalName) {
                m.isMainModule = true;
                mainModule = m;
            }

            /// Get to the point where we know what the exports are
            m.parser.readContents();
            m.parser.tokenise();
        }
        return m;
    }
    void removeModule(string canonicalName) {
        modules.remove(canonicalName);
    }
    Module[] allModules() {
        return modules.values;
    }
private:
}