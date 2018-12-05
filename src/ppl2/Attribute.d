module ppl2.Attribute;

import ppl2.internal;

T get(T)(Attribute[] attribs) {
    foreach(a; attribs) if(a.isA!T) return a.as!T;
    return null;
}

abstract class Attribute {
    enum ValidNode {
        FUNCTION,
        IF,
        MODULE,
        STRUCT
    }
    string name() { return "%s".format(this); }
    ValidNode[] getValidNodes() { return null; }
}
/// @bounds(min=0, max=200)
/// Applies to variables
final class RangeAttribute : Attribute {

}
/// @expect(true)
final class ExpectAttribute : Attribute {
    bool value;

    override string name() { return "@expect"; }
    override ValidNode[] getValidNodes() { return [ValidNode.IF]; }
}
/// @inline(true)
/// Applies to functions
final class InlineAttribute : Attribute {
    bool value;

    override string name() { return "@inline"; }
    override ValidNode[] getValidNodes() { return [ValidNode.FUNCTION]; }
}
/// @lazy
/// Applies to function parameters
final class LazyAttribute : Attribute {

}
/// @memoize
/// Applies to functions
final class MemoizeAttribute : Attribute {

}
/// @module(priority=1)
/// Applies to current module
final class ModuleAttribute : Attribute {
    int priority;

    override string name() { return "@module"; }
    override ValidNode[] getValidNodes() { return [ValidNode.MODULE]; }
}
/// @notnull
final class NotNullAttribute : Attribute {

}
/// @pack(true)
/// Applies to structs
final class PackAttribute : Attribute {
    override string name() { return "@pack"; }
    override ValidNode[] getValidNodes() { return [ValidNode.STRUCT]; }
}
/// @profile
/// Applies to functions
final class ProfileAttribute : Attribute {

}
