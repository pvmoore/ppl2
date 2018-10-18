module ide.util;

import ide.internal;
import std.path;
import std.file;

string normaliseDir(string path, bool makeAbsolute=false) {
    if(makeAbsolute) {
        path = asAbsolutePath(path).array;
    }
    path = asNormalizedPath(path).array;
    path = path.replace("\\", "/") ~ "/";
    return path;
}
string normaliseFile(string path,) {
    path = asNormalizedPath(path).array;
    path = path.replace("\\", "/");
    return path;
}

