module ide.IDEConfig;

import ide.internal;

final class IDEConfig {
    private const string FILENAME = "./ideconfig.toml";
    IDE ide;
    string currentProjectDir = "./projects/test/";
    Set!string recentProjects = new Set!string;

    this(IDE ide) {
        this.ide = ide;

        import std.file : exists;

        string filename = FILENAME;
        if(exists(filename)) {
            readConfig(filename);
        }
        writefln("currentProjectDir = %s", currentProjectDir);
        writefln("recentProjects    = %s", recentProjects);
    }
    void save() {
        writefln("Saving ide config");

        import std.stdio;

        scope file = File(FILENAME, "w");

        /// [[general]]
        file.writefln("[[general]]");
        file.writefln("currentProject = \"%s\"", currentProjectDir);



        file.writefln("recentProjects = %s", recentProjects.values);
    }
private:
    void readConfig(string tomlFile) {
        import ppl2.misc.toml;

        auto doc = TomlDocument.fromFile(tomlFile);

        string[] recentProjects;

        doc.iterate("general", (t) {
            this.currentProjectDir  = t.getString("currentProject", "./test/");
            recentProjects     = t.getStringArray("recentProjects");
        });

        filterRecentProjects(recentProjects);
    }
    void filterRecentProjects(string[] array) {
        import std.file : exists, isDir;

        foreach(rp; array) {
            if(isDir(rp)) {
                recentProjects.add(rp);
            } else {

            }
        }
    }
}
