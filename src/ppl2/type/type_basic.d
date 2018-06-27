module ppl2.type.type_basic;

import ppl2.internal;

final class BasicType : Type {
    int type;

    this(int type) {
        this.type = type;
    }
    int getEnum() const {
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
            return getEnum() <= right.getEnum();
        }
        return right.isReal;
    }
    Expression defaultInitialiser() {
        assert(isKnown);

        switch(type) with(Type) {
            case BOOL:
            case BYTE:
            case SHORT:
            case INT:
            case LONG:
            case HALF:
            case FLOAT:
            case DOUBLE:
                return LiteralNumber.makeConst(0, this);
            case VOID: assert(false, "addDefaultValue - type is VOID");
            default: assert(false, "addDefaultValue - How did we get here?");
        }
    }
    //===============================================================
    override string toString() {
        return "%s".format(g_typeToString[type]);
    }
}