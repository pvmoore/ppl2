module ide.project;

import ide.internal;
import std.path : isAbsolute;
import std.file : exists;
import ppl2;

final class Project {
private:

public:
    struct OpenFile {
        string filename;
        int line;
        bool active;
    }
    string name;
    string configFile;
    string directory;

    Config config;

    string[] excludeFiles;
    string[] excludeDirectories = [".target"];

    OpenFile[string] openFiles; // key = filename
    int[] currentLines;
    int[] currentColumns;

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
            parseProjectToml(filename);
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

        foreach(inc; config.getIncludes()) {
            if(relPath.startsWith(inc.baseModuleName~"/")) {
                return inc.absPath ~ relPath;
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

        /// [[general]]
        file.writefln("[[general]]");
        file.writefln("name = \"%s\"", name);
        file.writefln("configFile = \"%s\"", configFile);
        file.writefln("excludeFiles = %s", excludeFiles);
        file.writefln("excludeDirectories = %s", excludeDirectories);

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

        config = new ConfigReader(directory ~ configFile).read();
        writefln("%s", config);

        foreach(ref d; excludeDirectories) {
            d = normaliseDir(d);
            assert(!isAbsolute(d));
        }
        foreach(ref f; excludeFiles) {
            f = normaliseFile(f);
        }

        /// Remove any open files that don't exist
        foreach(k; openFiles.keys.idup) {
            if(!exists(getAbsPath(k))) openFiles.remove(k);
        }

        writefln("Project {");
        // general
        writefln("\tname               : %s", name);
        writefln("\tdirectory          : %s", directory);
        writefln("\tconfigFile         : %s", configFile);

        writefln("\texcludeFiles       : %s", excludeFiles);
        writefln("\texcludeDirectories : %s", excludeDirectories);
        // state
        writefln("\topenFiles          : %s", openFiles);
        writefln("}");
    }
    void parseProjectToml(string tomlFile) {

        auto doc = TomlDocument.fromFile(tomlFile);

        doc.iterate("general", (t) {
            this.name               = t.getString("name", "No-name");
            this.configFile         = t.getString("configFile");
            this.excludeFiles       = t.getStringArray("excludeFiles");
            this.excludeDirectories = t.getStringArray("excludeDirectories");
        });

        doc.iterate("openFile", (t) {
            this.openFiles[t.getString("name")] = OpenFile(
                t.getString("name"),
                t.getInt("line"),
                t.getInt("active")!=0,
            );
        });
    }
}