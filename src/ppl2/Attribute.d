module ppl2.Attribute;

import ppl2.internal;

T get(T)(Attribute[] attribs) {
    foreach(a; attribs) if(a.isA!T) return a.as!T;
    return null;
}

abstract class Attribute {

}
/// @bounds(min=0, max=200)
/// Applies to variables
final class RangeAttribute : Attribute {

}
/// @expect(true)
final class ExpectAttribute : Attribute {
    union {
        long i;
        double f;
    }
}
/// @inline(true)
/// Applies to functions
final class InlineAttribute : Attribute {
    bool value;
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
}
/// @notnull
final class NotNullAttribute : Attribute {

}
/// @pack(4)
/// Applies to structs
final class PackAttribute : Attribute {
    int value;
}
/// @profile
/// Applies to functions
final class ProfileAttribute : Attribute {

}
