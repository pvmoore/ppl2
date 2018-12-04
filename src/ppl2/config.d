module ppl2.config;

import ppl2.internal;
import std.array;
import std.path;

final class Config {
public:
    struct Lib {
        string baseModuleName;  // eg. "core"
        string absPath;
    }

    string mainFile;
    string basePath;
    string targetPath = "test/.target/";
    string targetExe  = "test.exe";
    string mainModuleCanonicalName;

    bool logDebug     = true;
    bool logTokens    = false;
    bool logParser    = false;
    bool logResolver  = false;

    bool writeASM = true;
    bool writeOBJ = true;
    bool writeAST = true;
    bool writeIR  = true;

    bool nullChecks             = true;
    bool enableAsserts          = true;
    bool enableInlining         = true;
    bool enableOptimisation     = true;
    bool fastMaths              = true;
    bool enableLink             = true;

    bool disableInternalLinkage = false;
    int maxErrors               = int.max;

    bool dumpStats        = true;
    bool dumpDependencies = true;
    bool dumpModuleRefs   = true;

    Lib[string] libs;   // key = baseModuleName

    this(string mainFilePath) {
        setToDebug();
        addLibs();

        auto normalisedPath = cast(string)mainFilePath.asNormalizedPath.array;

        mainFile = relativePath(normalisedPath).replace("\\", "/");
        basePath = dirName(mainFile);

        if(basePath.length > 0) basePath ~= "/";

        generateTargetDirectories();
        getMainModuleCanonicalName();
    }
    ///
    /// Return the full path including the module filename and extension
    ///
    string getFullModulePath(string canonicalName) {
        auto baseModuleName = splitCanonicalName(canonicalName)[0];
        auto path           = basePath;

        foreach(lib; libs) {
            if(lib.baseModuleName==baseModuleName) {
                path = lib.absPath;
            }
        }

        assert(path.endsWith("/"));

        return path ~ canonicalName.replace("::", "/") ~ ".p2";
    }
    override string toString() {
        auto buf = new StringBuffer;
        buf.add("Main file .... %s\n".format(mainFile));
        buf.add("Base path .... %s\n".format(basePath));
        buf.add("Target path .. %s\n".format(targetPath));
        buf.add("Target exe ... %s\n".format(targetExe));
        return buf.toString();
    }
private:
    /// eg. "core::console" -> ["core", "console"]
    static string[] splitCanonicalName(string canonicalName) {
        assert(canonicalName);
        return canonicalName.split("::");
    }
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
        nullChecks         = true;
        enableAsserts      = true;
        enableInlining     = true;  /// set this to false later
        enableOptimisation = true;  /// set this to false later
    }
    void setToRelease() {
        nullChecks         = false;
        enableAsserts      = false;
        enableInlining     = true;
        enableOptimisation = true;
    }
    void addLibs() {
        libs["core"] = Lib("core", "./libs/");
        libs["std"]  = Lib("std", "./libs/");
    }
}