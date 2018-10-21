module ppl2.config;

import ppl2.internal;
import std.array;
import std.path;

struct Lib {
    string baseModuleName;  // eg. "core"
    string absPath;
}

final class Config {
    Module[/*canonicalName*/string] modules;
    Mutex lock;
public:
    string mainFile;
    string basePath;
    string targetPath = "test/.target/";
    string targetExe  = "test.exe";
    string mainModuleCanonicalName;
    Module mainModule;

    bool logDebug     = true;
    bool logTokens    = false;
    bool logParser    = false;
    bool logResolver  = false;

    bool writeASM = true;
    bool writeOBJ = true;
    bool writeAST = true;

    bool nullChecks    = true;
    bool enableAsserts = true;

    bool dumpStats        = true;
    bool dumpDependencies = true;
    bool dumpModuleRefs   = true;

    Lib[string] libs;   // key = baseModuleName

    this(string mainFilePath) {
        this.lock = new Mutex;

        setToDebug();
        addLibs();

        auto normalisedPath = cast(string)mainFilePath.asNormalizedPath.array;

        mainFile = relativePath(normalisedPath).replace("\\", "/");
        basePath = dirName(mainFile);

        if(basePath.length > 0) basePath ~= "/";

        generateTargetDirectories();
        getMainModuleCanonicalName();

        writefln("\nPPL %s", VERSION);
        writefln("Main file .... %s", mainFile);
        writefln("Base path .... %s", basePath);
        writefln("Target path .. %s", targetPath);
        writefln("Target exe ... %s", targetExe);
        writefln("");
    }
    Module getOrCreateModule(string canonicalName) {
        lock.lock();
        scope(exit) lock.unlock();

        auto m = modules.get(canonicalName, null);
        if(!m) {
            m = new Module(canonicalName, PPL2.llvmWrapper, this);
            modules[canonicalName] = m;

            if(canonicalName==mainModuleCanonicalName) {
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
    void getMainModuleCanonicalName() {
        auto rel = mainFile[basePath.length..$];
        mainModuleCanonicalName = rel.stripExtension.replace("/", ".").replace("\\", ".");
    }
    void generateTargetDirectories() {
        createTargetDir("tok/");
        createTargetDir("ast/");
        createTargetDir("ir/");
        createTargetDir("ir_opt/");
        createTargetDir("bc/");
    }
    void createTargetDir(string dir) {
        import std.file : exists, mkdir;
        string path = targetPath ~ dir;
        if(!exists(path)) {
            mkdir(path);
        }
    }
    void setToDebug() {
        nullChecks    = true;
        enableAsserts = true;
    }
    void setToRelease() {
        nullChecks    = false;
        enableAsserts = false;
    }
    void addLibs() {
        libs["core"] = Lib("core", "./libs/");
        libs["std"]  = Lib("std", "./libs/");
    }
}