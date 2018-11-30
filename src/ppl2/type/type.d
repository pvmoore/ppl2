module ppl2.type.type;

import ppl2.internal;

interface Type {
    /// Category
    enum : int {
        UNKNOWN = 0,
        BOOL, BYTE, SHORT, INT, LONG, HALF, FLOAT, DOUBLE,
        VOID,
        /// All lower than STRUCT are BasicTypes
        STRUCT,
        TUPLE,
        ENUM,
        ARRAY,
        FUNCTION
    }
/// Override these
    int category() const;
    bool isKnown();
    bool exactlyMatches(Type other);
    bool canImplicitlyCastTo(Type other);
    LLVMTypeRef getLLVMType();
///
    //-------------------------------------
    final bool isFloat() const    { return category()==FLOAT; }
    final bool isDouble() const   { return category()==DOUBLE; }
    final bool isInt() const      { return category()==INT; }
    final bool isLong() const     { return category()==LONG; }
    final bool isPtr() const      { return this.isA!PtrType; }
    final bool isValue() const    { return !isPtr; }
    final bool isUnknown()        { return !isKnown(); }
    final bool isVoid() const     { return category()==VOID; }
    final bool isBool() const     { return category()==BOOL; }
    final bool isReal() const     { int e = category(); return e==HALF || e==FLOAT || e==DOUBLE; }
    final bool isInteger() const  { int e = category(); return e==BYTE || e==SHORT || e==INT || e==LONG; }
    final bool isBasicType()      { return category() <= VOID && category()!=UNKNOWN; }
    final bool isStruct() const   { return category()==STRUCT; }
    final bool isArray() const    { return category()==ARRAY; }
    final bool isEnum() const     { return category()==ENUM; }
    final bool isFunction() const { return category()==FUNCTION; }
    final bool isTuple() const    { return category()==TUPLE; }

    final bool isAlias() const {
        if(this.as!Alias !is null) return true;
        auto ptr = this.as!PtrType;
        return ptr && ptr.decoratedType.isAlias;
    }

    final getBasicType() {
        auto basic = this.as!BasicType; if(basic) return basic;
        auto def   = this.as!Alias;     if(def) return def.type.getBasicType;
        auto ptr   = this.as!PtrType;   if(ptr) return ptr.decoratedType().getBasicType;
        return null;
    }
    final Alias getAlias() {
        auto alias_ = this.as!Alias;   if(alias_) return alias_;
        auto ptr    = this.as!PtrType; if(ptr) return ptr.decoratedType().getAlias;
        return null;
    }
    final Enum getEnum() {
        auto e   = this.as!Enum;    if(e) return e;
        auto ptr = this.as!PtrType; if(ptr) return ptr.decoratedType().getEnum();
        return null;
    }
    final FunctionType getFunctionType() {
        if(category != Type.FUNCTION) return null;
        auto f      = this.as!FunctionType; if(f) return f;
        auto alias_ = this.as!Alias;        if(alias_) return alias_.type.getFunctionType;
        auto ptr    = this.as!PtrType;      if(ptr) return ptr.decoratedType().getFunctionType;
        assert(false, "How did we get here?");
    }
    final Struct getStruct() {
        if(category!=Type.STRUCT) return null;
        auto ns     = this.as!Struct;      if(ns) return ns;
        auto alias_ = this.as!Alias;       if(alias_) return alias_.type.getStruct;
        auto ptr    = this.as!PtrType;     if(ptr) return ptr.decoratedType.getStruct;
        assert(false, "How did we get here?");
    }
    final Tuple getTuple() {
        if(!isTuple && !isStruct) return null;
        auto st     = this.as!Tuple;      if(st) return st;
        auto alias_ = this.as!Alias;      if(alias_) return alias_.type.getTuple;
        auto ptr    = this.as!PtrType;    if(ptr) return ptr.decoratedType.getTuple;
        assert(false, "How did we get here?");
    }
    final ArrayType getArrayType() {
        if(category != Type.ARRAY) return null;
        auto a      = this.as!ArrayType; if(a) return a;
        auto alias_ = this.as!Alias;     if(alias_) return alias_.type.getArrayType;
        auto ptr    = this.as!PtrType;   if(ptr) return ptr.decoratedType().getArrayType;
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
    if(a.isTuple || b.isTuple) {
        // todo - some clever logic here
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
        return a.category() > b.category() ? a : b;
    }
    if(a.isReal) return a;
    if(b.isReal) return b;
    return a;
}
///
/// Get the largest type of all elements.
/// If there is no common type then return null
///
Type getBestFit(Type[] types) {
    if(types.length==0) return TYPE_UNKNOWN;

    Type t = types[0];
    if(types.length==1) return t;

    foreach(e; types[1..$]) {
        t = getBestFit(t, e);
        if(t is null) {
            return null;
        }
    }
    return t;
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
    if(left.category() != right.category()) return false;
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
        return left.category==right.category;
    }
    /// Do the base checks now
    return true;
}
int size(Type t) {
    if(t.isPtr) return 8;
    final switch(t.category) with(Type) {
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
        case STRUCT: return t.getStruct.memberVariableTypes().map!(it=>it.size).sum;
        case TUPLE: return t.getTuple.memberVariableTypes().map!(it=>it.size).sum;
        case ARRAY: return t.getArrayType.countAsInt()*t.getArrayType.subtype.size();
        case ENUM: return t.getEnum().elementType.size();
    }
}
LLVMValueRef zeroValue(Type t) {
    if(t.isPtr) {
        return constNullPointer(t.getLLVMType());
    }
    final switch(t.category) with(Type) {
        case UNKNOWN:
        case STRUCT:
        case TUPLE:
        case ARRAY:
        case FUNCTION:
        case VOID:
            assert(false, "zeroValue - type is %s".format(t));
        case BOOL: return constI8(FALSE);
        case BYTE: return constI8(0);
        case SHORT: return constI16(0);
        case INT: return constI32(0);
        case LONG: return constI64(0);
        case HALF: return constF16(0);
        case FLOAT: return constF32(0);
        case DOUBLE: return constF64(0);
        case ENUM: return t.getEnum().elementType.zeroValue;
    }
}
Expression initExpression(Type t) {
    if(t.isPtr) {
        return LiteralNull.makeConst(t);
    }
    final switch(t.category) with(Type) {
        case UNKNOWN:
        case VOID:
            assert(false, "initExpression - type is %s".format(t));
        case STRUCT:
        case TUPLE:
        case ARRAY:
        case FUNCTION:
            assert(false, "initExpression - implement me");
        case ENUM:
            return t.getEnum().firstValue();
        case BOOL:
        case BYTE:
        case SHORT:
        case INT:
        case LONG:
        case HALF:
        case FLOAT:
        case DOUBLE:
            return LiteralNumber.makeConst(0, t);
    }
}
string toString(Type[] types) {
    auto buf = new StringBuffer;
    foreach(i, t; types) {
        if(i>0) buf.add(",");
        buf.add("%s".format(t));
    }
    return buf.toString;
}