module ppl2.type.type_basic;

import ppl2.internal;

final class BasicType : Type {
    int type;

    this(int type) {
        this.type = type;
    }
    int category() const {
        return type;
    }
    bool isKnown() {
        return type!=UNKNOWN;
    }
    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type

        return true;
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isBasicType) return false;

        auto right = other.getBasicType;

        if(isVoid || right.isVoid) return false;

        if(isReal==right.isReal) {
            /// Allow bool -> any other BasicType
            return category() <= right.category();
        }
        return right.isReal;
    }
    LLVMTypeRef getLLVMType() {
        switch(type) with(Type) {
            case BOOL:
            case BYTE: return i8Type();
            case SHORT: return i16Type();
            case INT: return i32Type();
            case LONG: return i64Type();
            case HALF: return f16Type();
            case FLOAT: return f32Type();
            case DOUBLE: return f64Type();
            case VOID: return voidType();
            default:
                assert(false, "type is %s".format(type));
        }
    }
    //===============================================================
    override string toString() {
        return "%s".format(g_typeToString[type]);
    }
}

