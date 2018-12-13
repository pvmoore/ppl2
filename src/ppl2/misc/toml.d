module ppl2.misc.toml;

import ppl2.internal;
import toml;

final class TomlDocument {
private:
    TOMLDocument doc;
public:
    static TomlDocument fromFile(string filename) {
        import std.file : read;
        auto i = new TomlDocument;

        auto text = cast(string)read(filename);
        i.doc = parseTOML(text);
        return i;
    }
    void iterate(string table, void delegate(TOMLValue[string]) func) {
        if(table in doc) {
            foreach(t; doc[table].array) {
                func(t.table);
            }
        }
    }
}
string getString(TOMLValue[string] table, string key, string defaultValue="") {
    return table.get(key, TOMLValue(defaultValue)).str;
}
string[] getStringArray(TOMLValue[string] table, string key) {
    return table.get(key, TOMLValue([""])).array.map!(it=>it.str).array;
}
int getInt(TOMLValue[string] table, string key, int defaultValue=0) {
    return table.get(key, TOMLValue(defaultValue)).integer.to!int;
}