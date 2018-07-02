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

    bool foldConstants = true;  /// This MUST be enabled if you use consts
                                /// to initialise array counts for example

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
        import std.file : exists, mkdir;

        string astpath = targetPath ~ "ast/";
        if(!exists(astpath)) {
            mkdir(astpath);
        }

        string irpath = targetPath ~ "ir/";
        if(!exists(irpath)) {
            mkdir(irpath);
        }

        string bcpath = targetPath ~ "bc/";
        if(!exists(bcpath)) {
            mkdir(bcpath);
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