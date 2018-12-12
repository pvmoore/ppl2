module ide.project;

import ide.internal;
import std.path : isAbsolute;
import std.file : exists;
import ppl2;

final class Project {
public:
    struct OpenFile {
        string filename;
        int line;
        bool active;
    }
    struct Lib {
        string name;
        string directory;
    }
    string name;
    string mainFile;
    string directory;
    string targetDirectory = ".target";

    Config config;

    string[] excludeFiles;
    string[] excludeDirectories = [".target"];

    OpenFile[string] openFiles; // key = filename
    int[] currentLines;
    int[] currentColumns;

    Lib[string] libs;   /// key = lib name

    this() {
        name      = "Test";
        directory = normaliseDir("/pvmoore/d/apps/PPL2/test", true);

        initialise();
    }
    this(string directory) {
        import toml;
        import std.file;
        assert(exists(directory) && isDir(directory));

        this.directory = normaliseDir(directory, true);
        auto filename = this.directory ~ "project.toml";

        //writefln("directory:%s", this.directory);
        //writefln("filename :%s", filename);

        if(exists(filename)) {
            parseProjectToml(cast(string)read(filename));
            initialise();
        } else {
            writefln("Project file does not exist");
        }
    }
    ///
    /// Returns the absolute path for given src file with relative path
    ///
    string getAbsPath(string relPath) {
        assert(!isAbsolute(relPath));

        foreach(k, lib; libs) {
            if(relPath.startsWith(k)) {
                return lib.directory ~ relPath;
            }
        }

        return directory ~ relPath;
    }
    OpenFile* getOpenFile(string filename) {
        auto p = filename in openFiles;
        if(p) return p;
        return null;
    }
    OpenFile* getActiveOpenFile() {
        foreach(k,v; openFiles) {
            if(v.active) return &openFiles[k];
        }
        return null;
    }
    void updateOpenFiles(Project.OpenFile[] o) {
        openFiles.clear();
        foreach(f; o) {
            openFiles[f.filename] = f;
        }
    }
    void save() {
        import std.stdio;
        writefln("save project");

        scope file = File(directory ~ "project.toml", "w");

        //scope file = stdout;

        /// [[general]]
        file.writefln("[[general]]");
        file.writefln("name = \"%s\"", name);
        file.writefln("mainFile = \"%s\"", mainFile);
        file.writefln("targetDirectory = \"%s\"", targetDirectory);
        file.writefln("excludeFiles = %s", excludeFiles);
        file.writefln("excludeDirectories = %s", excludeDirectories);

        /// [[release]]
        file.writefln("\n[[release]]");
        file.writefln("optLevel = %s", 3);

        /// [[debug]]
        file.writefln("\n[[debug]]");

        /// [[dependency]]
        file.writefln("\n[[dependency]]");
        file.writefln("name = \"%s\"", "blah");
        file.writefln("directory = \"%s\"", "./libs");

        /// [[openFile]]
        foreach(o; openFiles.values) {
            file.writefln("\n[[openFile]]");
            file.writefln("name = \"%s\"", o.filename);
            file.writefln("line = %s", o.line);
            file.writefln("active = %s", o.active ? 1 : 0);
        }
    }
private:
    void initialise() {
        assert(exists(directory));

        /// Add core and std libs
        libs["core"] = Lib("core", "./libs");
        libs["std"]  = Lib("std",  "./libs");

        foreach(ref d; excludeDirectories) {
            d = normaliseDir(d);
            assert(!isAbsolute(d));
        }
        foreach(ref f; excludeFiles) {
            f = normaliseFile(f);
        }
        foreach(k,v; libs) {
            libs[k].directory = normaliseDir(v.directory, true);
        }

        /// Remove any open files that don't exist
        foreach(k; openFiles.keys.idup) {
            if(!exists(getAbsPath(k))) openFiles.remove(k);
        }

        targetDirectory = normaliseDir(targetDirectory);

        writefln("Project {");
        // general
        writefln("\tname               : %s", name);
        writefln("\tmainFile           : %s", mainFile);
        writefln("\tdirectory          : %s", directory);
        writefln("\ttargetDirectory    : %s", targetDirectory);
        writefln("\texcludeFiles       : %s", excludeFiles);
        writefln("\texcludeDirectories : %s", excludeDirectories);
        // state
        writefln("\topenFiles          : %s", openFiles);
        writefln("\tdependencies       : %s", libs);
        writefln("}");

        config = new Config(directory ~ mainFile);
        writefln("%s", config);
    }
    void parseProjectToml(string text) {
        import toml;
        import std.conv : to;

        auto doc = parseTOML(text);

        foreach(map; doc["general"].array) {
            auto t = map.table;
            this.name            = t.get("name", TOMLValue("No-name")).str;
            this.mainFile        = t.get("mainFile", TOMLValue("")).str;
            this.targetDirectory = t.get("targetDirectory", TOMLValue("target")).str;
            this.excludeFiles    = t.get("excludeFiles", TOMLValue([""]))
                                         .array.map!(it=>it.str).array;
            this.excludeDirectories = t.get("excludeDirectories", TOMLValue([""]))
                                               .array.map!(it=>it.str).array;
        }
        if("openFile" in doc) {
            foreach(map; doc["openFile"].array) {
                auto t = map.table;
                this.openFiles[t["name"].str] = OpenFile(
                    t["name"].str,
                    t.get("line", TOMLValue(0)).integer.to!int,
                    t.get("active", TOMLValue(0)).integer!=0,
                );
            }
        }
        if("dependency" in doc) {
            foreach(map; doc["dependency"].array) {
                auto t = map.table;
                libs[t["name"].str] = Lib(
                    t["name"].str,
                    t["directory"].str
                );
            }
        }
    }
}