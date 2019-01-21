module ide.IDEConfig;

import ide.internal;

final class IDEConfig {
    private const string FILENAME = "./ideconfig.toml";
    IDE ide;
    string currentProjectDir = "./projects/test/";

    this(IDE ide) {
        this.ide = ide;

        import std.file : exists;
        string filename = FILENAME;
        if(exists(filename)) {
            readConfig(filename);
        }
        writefln("currentProjectDir = %s", currentProjectDir);
    }
    void save() {
        writefln("Saving ide config");

        import std.stdio;

        scope file = File(FILENAME, "w");

        /// [[general]]
        file.writefln("[[general]]");
        file.writefln("currentProject = \"%s\"", currentProjectDir);
    }
private:
    void readConfig(string tomlFile) {
        import ppl2.misc.toml;

        auto doc = TomlDocument.fromFile(tomlFile);

        doc.iterate("general", (t) {
            this.currentProjectDir  = t.getString("currentProject", "./test/");
        });
    }
}
