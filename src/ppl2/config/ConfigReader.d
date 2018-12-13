module ppl2.config.ConfigReader;

import ppl2.internal;
import toml;
import std.conv : to;
import std.path : asNormalizedPath, dirName, isAbsolute, relativePath;

final class ConfigReader {
    string tomlFile;
    string basePath;
public:
    this(string tomlFile) {
        import std.array : replace;

        auto normalisedPath = cast(string)tomlFile.asNormalizedPath.array;

        this.tomlFile = relativePath(normalisedPath).replace("\\", "/");
        this.basePath = dirName(this.tomlFile);

        if(basePath.length > 0) basePath ~= "/";
    }
    Config read() {

        bool isRelease = true;
        string mainFile;
        string targetPath;
        string targetExe;

        auto doc = TomlDocument.fromFile(tomlFile);

        doc.iterate("general", (t) {
            isRelease  = t.getString("build", "debug")=="release";
            mainFile   = t.getString("mainFile");
            targetPath = t.getString("targetPath", ".target");
            targetExe  = t.getString("targetExe");
        });

        import std.file : exists;
        if(!exists(basePath ~ mainFile)) {
            throw new Error("mainFile '%s' does not exist".format(basePath~mainFile));
        }

        Config config     = new Config;
        config.mainFile   = mainFile;
        config.basePath   = basePath;
        config.targetPath = basePath ~ targetPath;
        config.targetExe  = targetExe;

        if(isRelease) {
            config.setToRelease();

            doc.iterate("release", (t) {
                // todo
            });
        } else {
            config.setToDebug();

            doc.iterate("debug", (t) {
                // todo
            });
        }

        /// Standard libs
        config.addInclude("core", "./libs/");
        config.addInclude("std", "./libs/");

        /// User libs
        doc.iterate("src-dependency", (t) {
            config.addInclude(t.getString("name"), getString(t, "directory"));
        });

        doc.iterate("lib-dependency", (t) {
            string key = config.isDebug ? "debugLibs" : "releaseLibs";

            foreach(lib; t.getStringArray(key)) {
                config.addLib(lib);
            }
        });
        doc.iterate("linker", (t) {
            bool enable = t.getInt("enable")==1;
            config.enableLink = enable;
        });
        config.initialise();

        return config;
    }
private:
    string getString(TOMLValue[string] table, string key, string defaultValue="") {
        return table.get(key, TOMLValue(defaultValue)).str;
    }
    string[] getStringArray(TOMLValue[string] table, string key) {
        return table.get(key, TOMLValue([""])).array.map!(it=>it.str).array;
    }
    int getInt(TOMLValue[string] table, string key, int defaultValue=0) {
        return table.get(key, TOMLValue(defaultValue)).integer.to!int;
    }
}
