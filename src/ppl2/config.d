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

    bool dce           = true; /// dead code elimination

    bool nullChecks    = true;
    bool enableAsserts = true;

    this(string mainFilePath) {
        import std.path;
        import std.array;

        setToDebug();

        auto normalisedPath = cast(string)mainFilePath.asNormalizedPath.array;

        mainFile = relativePath(normalisedPath).replace("\\", "/");
        basePath = dirName(mainFile);

        if(basePath.length > 0) basePath ~= "/";

        generateTargetDirectories();
    }
private:
    void generateTargetDirectories() {
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
}