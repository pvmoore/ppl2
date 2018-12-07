module ppl2.Attribute;

import ppl2.internal;

T get(T)(Attribute[] attribs) {
    foreach(a; attribs) if(a.isA!T) return a.as!T;
    return null;
}

abstract class Attribute {
    enum Type {
        EXPECT, INLINE, LAZY, MEMOIZE, MODULE, NOTNULL, PACK, POD, PROFILE, RANGE
    }
    string name;
    Type type;
}

/// @expect(true)
final class ExpectAttribute : Attribute {
    bool value;

    this() {
        name = "@expect";
        type = Type.EXPECT;
    }
}
/// @inline(true)
/// Applies to functions
final class InlineAttribute : Attribute {
    bool value;

    this() {
        name = "@inline";
        type = Type.INLINE;
    }
}
/// @lazy
/// Applies to function parameters
final class LazyAttribute : Attribute {
    this() {
        name = "@lazy";
        type = Type.LAZY;
    }
}
/// @memoize
/// Applies to functions
final class MemoizeAttribute : Attribute {
    this() {
        name = "@memoize";
        type = Type.MEMOIZE;
    }
}
/// @module(priority=1)
/// Applies to current module
final class ModuleAttribute : Attribute {
    int priority;
    this() {
        name = "@module";
        type = Type.MODULE;
    }
}
/// @notnull
final class NotNullAttribute : Attribute {
    this() {
        name = "@notnull";
        type = Type.NOTNULL;
    }
}
/// @pack(true)
/// Applies to structs
final class PackAttribute : Attribute {
    this() {
        name = "@pack";
        type = Type.PACK;
    }
}
final class PodAttribute : Attribute {
    this() {
        name = "@pod";
        type = Type.POD;
    }
}
/// @profile
/// Applies to functions
final class ProfileAttribute : Attribute {
    this() {
        name = "@profile";
        type = Type.PROFILE;
    }
}
/// @bounds(min=0, max=200)
/// Applies to variables
final class RangeAttribute : Attribute {
    this() {
        name = "@range";
        type = Type.RANGE;
    }
}
