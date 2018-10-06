module ppl2.config;

import ppl2.internal;
///
/// Singleton Config
///
Config getConfig() {
    return g_config;
}
void setConfig(Config c) {
    g_config = c;
}

struct Lib {
    string baseModuleName;  // "core"
    string absPath;
}

final class Config {
public:
    string mainFile;
    string basePath;
    string targetPath = "test/.target/";
    string targetExe  = "test.exe";

    bool logDebug     = true;
    bool logTokens    = false;
    bool logParser    = false;
    bool logResolver  = false;

    bool writeASM = true;
    bool writeOBJ = true;

    bool nullChecks    = true;
    bool enableAsserts = true;

    Lib[string] libs;   // key = baseModuleName

    this(string mainFilePath) {
        import std.path;
        import std.array;

        setToDebug();
        addLibs();

        auto normalisedPath = cast(string)mainFilePath.asNormalizedPath.array;

        mainFile = relativePath(normalisedPath).replace("\\", "/");
        basePath = dirName(mainFile);

        if(basePath.length > 0) basePath ~= "/";

        generateTargetDirectories();
    }
private:
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