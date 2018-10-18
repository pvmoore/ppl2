module ide.project;

import ide.internal;
import std.path : isAbsolute;

final class Project {
public:
    string name;
    string directory;
    string targetDirectory = ".target";

    string[] excludedFiles;
    string[] excludedDirs = [".target"];

    string[string] libs; /// key = lib name, value = directory

    string[] openFiles = [];

    this() {
        name      = "Test";
        directory = normaliseDir("/pvmoore/d/apps/PPL2/test", true);

        libs["core"] = "./libs";

        assert(FQN!"std.file".exists(directory));

        foreach(ref d; excludedDirs) {
            d = normaliseDir(d);
            assert(!isAbsolute(d));
        }
        foreach(ref f; excludedFiles) {
            f = normaliseFile(f);
        }
        foreach(k,v; libs) {
            libs[k] = normaliseDir(v, true);
        }
    }
    this(string filename) {
        // todo
    }
    ///
    /// Returns the absolute path for given src file with relative path
    ///
    string getAbsPath(string relPath) {
        assert(!isAbsolute(relPath));

        if(relPath.startsWith("core")) {
            return libs["core"] ~ relPath;
        }
        return directory ~ relPath;
    }
    void save() {
        // todo
    }
private:
}