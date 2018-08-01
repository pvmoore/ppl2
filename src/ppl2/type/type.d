module ppl2.type.type;

import ppl2.internal;

interface Type {
    enum : int {
        UNKNOWN = 0,
        BOOL, BYTE, SHORT, INT, LONG, HALF, FLOAT, DOUBLE,
        VOID,
        /// All lower than STRUCT are BasicTypes
        NAMED_STRUCT,
        ANON_STRUCT,
        ARRAY,
        FUNCTION
    }
/// Override these
    int getEnum() const;
    bool isKnown();
    bool exactlyMatches(Type other);
    bool canImplicitlyCastTo(Type other);
    LLVMTypeRef getLLVMType();
    string prettyString();
    //-------------------------------------
pragma(inline,true) {
    final bool isFloat() const { return getEnum()==FLOAT; }
    final bool isDouble() const { return getEnum()==DOUBLE; }
    final bool isInt() const { return getEnum()==INT; }
    final bool isLong() const { return getEnum()==LONG; }
    final bool isPtr() const { return this.isA!PtrType; }
    final bool isValue() const { return !isPtr; }
    final bool isUnknown() { return !isKnown(); }
    final bool isVoid() const { return getEnum()==VOID; }
    final bool isBool() const { return getEnum()==BOOL; }
    final bool isReal() const { int e = getEnum(); return e==HALF || e==FLOAT || e==DOUBLE; }
    final bool isInteger() const { int e = getEnum(); return e==BYTE || e==SHORT || e==INT || e==LONG; }
    final bool isBasicType() { return this.getBasicType !is null; }
    final bool isStruct() const { return isNamedStruct() || isAnonStruct(); }
    final bool isNamedStruct() const { return getEnum==NAMED_STRUCT; }
    final bool isAnonStruct() const { return getEnum==ANON_STRUCT; }
    final bool isFunction() const {  return getEnum()==FUNCTION; }
    final bool isArray() const { return getEnum()==ARRAY; }

    final bool isDefine() const {
        if(this.as!Define !is null) return true;
        auto ptr = this.as!PtrType;
        return ptr && ptr.decoratedType.isDefine;
    }
    final getBasicType() {
        auto basic = this.as!BasicType; if(basic) return basic;
        auto def   = this.as!Define; if(def) return def.type.getBasicType;
        auto ptr   = this.as!PtrType; if(ptr) return ptr.decoratedType().getBasicType;
        return null;
    }
    final Define getDefine() {
        auto def = this.as!Define; if(def) return def;
        auto ptr = this.as!PtrType; if(ptr) return ptr.decoratedType().getDefine;
        return null;
    }
    final ArrayType getArrayType() {
        if(getEnum != Type.ARRAY) return null;
        auto a   = this.as!ArrayType; if(a) return a;
        auto def = this.as!Define; if(def) return def.type.getArrayType;
        auto ptr = this.as!PtrType; if(ptr) return ptr.decoratedType().getArrayType;
        assert(false, "How did we get here?");
    }
    final FunctionType getFunctionType() {
        if(getEnum != Type.FUNCTION) return null;
        auto f   = this.as!FunctionType; if(f) return f;
        auto def = this.as!Define; if(def) return def.type.getFunctionType;
        auto ptr = this.as!PtrType; if(ptr) return ptr.decoratedType().getFunctionType;
        assert(false, "How did we get here?");
    }
    final NamedStruct getNamedStruct() {
        if(getEnum!=Type.NAMED_STRUCT) return null;
        auto ns  = this.as!NamedStruct; if(ns) return ns;
        auto def = this.as!Define; if(def) return def.type.getNamedStruct;
        auto ptr = this.as!PtrType; if(ptr) return ptr.decoratedType.getNamedStruct;
        assert(false, "How did we get here?");
    }
    final AnonStruct getAnonStruct() {
        if(!isStruct) return null;
        auto st  = this.as!AnonStruct; if(st) return st;
        auto ns  = this.as!NamedStruct; if(ns) return ns.type;
        auto def = this.as!Define; if(def) return def.type.getAnonStruct;
        auto ptr = this.as!PtrType; if(ptr) return ptr.decoratedType.getAnonStruct;
        assert(false, "How did we get here?");
    }
    /// Return the non pointer version of this type
    final Type getValueType() {
        auto ptr = this.as!PtrType; if(ptr) return ptr.decoratedType;
        return this;
    }
    final int getPtrDepth() {
        if(this.isPtr) return this.as!PtrType.getPtrDepth;
        return 0;
    }
} /// end of inline block
}
//=============================================================================================
Type[] types(Expression[] e) {
    return e.map!(it=>it.getType).array;
}
bool areKnown(Type[] t) {
	return t.all!(it=>it !is null && it.isKnown);
}
bool areCompatible(Type a, Type b) {
    if(a.canImplicitlyCastTo(b)) return true;
    return b.canImplicitlyCastTo(a);
}
///
/// Return the largest type of a or b.
/// Return null if they are not compatible.
///
Type getBestFit(Type a, Type b) {
    if(a.exactlyMatches(b)) return a;
    if(a.isPtr || b.isPtr) {
        return null;
    }
    if(a.isStruct || b.isStruct) {
        // todo - some clever logic here
        return null;
    }
    if(a.isFunction || b.isFunction) {
        return null;
    }
    if(a.isArray || b.isArray) {
        return null;
    }
    if(a.isVoid || b.isVoid) {
        return null;
    }
    if(a.isReal == b.isReal) {
        return a.getEnum() > b.getEnum() ? a : b;
    }
    if(a.isReal) return a;
    if(b.isReal) return b;
    return a;
}
//============================================================================================== exactlyMatch
bool exactlyMatch(Type[] a, Type[] b) {
    if(a.length != b.length) return false;
    foreach(i, left; a) {
        if(!left.exactlyMatches(b[i])) return false;
    }
    return true;
}
/// Do the common checks
bool prelimExactlyMatches(Type left, Type right) {
    if(left.isUnknown || right.isUnknown) return false;
    if(left.getEnum() != right.getEnum()) return false;
    if(left.getPtrDepth() != right.getPtrDepth()) return false;
    return true;
}
//====================================================================================== canImplicitlyCastTo
bool canImplicitlyCastTo(Type[] a, Type[] b) {
    if(a.length != b.length) return false;
    foreach(i, left; a) {
        if(!left.canImplicitlyCastTo(b[i])) return false;
    }
    return true;
}
/// Do the common checks
bool prelimCanImplicitlyCastTo(Type left, Type right) {
    if(left.isUnknown || right.isUnknown) return false;
    if(left.getPtrDepth() != right.getPtrDepth()) return false;
    if(left.isPtr()) {
        if(right.isVoid) {
            /// void* can contain any other pointer
            return true;
        }
        /// pointers must be exactly the same base type
        return left.getEnum==right.getEnum;
    }
    /// Do the base checks now
    return true;
}
void getChildTypes(Type t, Array!Type array) {
    if(t.isAnonStruct()) {
        array.add(t.getAnonStruct.memberVariableTypes());
    } else if(t.isFunction) {
        array.add(t.getFunctionType.paramTypes());
        array.add(t.getFunctionType.returnType());
    } else if(t.isArray) {
        array.add(t.getArrayType.subtype);
    }
}
int size(Type t) {
    if(t.isPtr) return 8;
    final switch(t.getEnum) with(Type) {
        case UNKNOWN:
        case FUNCTION:
        case VOID:
            assert(false, "size - %s has no size".format(t));
        case BOOL:
        case BYTE: return 1;
        case SHORT: return 2;
        case INT: return 4;
        case LONG: return 8;
        case HALF: return 2;
        case FLOAT: return 4;
        case DOUBLE: return 8;
        case NAMED_STRUCT: return t.getNamedStruct.type.memberVariableTypes().map!(it=>it.size).sum;
        case ANON_STRUCT: return t.getAnonStruct.memberVariableTypes().map!(it=>it.size).sum;
        case ARRAY: return t.getArrayType.countAsInt()*t.getArrayType.subtype.size();
    }
}
LLVMValueRef zero(Type t) {
    if(t.isPtr) {
        return constNullPointer(t.getLLVMType());
    }
    final switch(t.getEnum) with(Type) {
        case UNKNOWN:
        case NAMED_STRUCT:
        case ANON_STRUCT:
        case FUNCTION:
        case VOID:
            assert(false, "zero - type is %s".format(t));
        case BOOL: return constI8(FALSE);
        case BYTE: return constI8(0);
        case SHORT: return constI16(0);
        case INT: return constI32(0);
        case LONG: return constI64(0);
        case HALF: return constF16(0);
        case FLOAT: return constF32(0);
        case DOUBLE: return constF64(0);
    }
    assert(false);
}
string prettyString(Type[] types) {
    auto buf = new StringBuffer;
    foreach(i, t; types) {
        if(i>0) buf.add(", ");
        buf.add(t.prettyString);
    }
    return buf.toString;
}