module ppl2.type.define;

import ppl2.internal;

class Define : Statement, Type {
    string name;
    string moduleName;
    bool isImport;
    int numRefs;

    Type type;

    this() {
        type = TYPE_UNKNOWN;
    }

/// ASTNode
    override bool isResolved() {
        if(isImport) return true;
        return type.isKnown;
    }
    final override NodeID id() const { return NodeID.DEFINE; }
    override Type getType() { return type; }
/// Type
    final int getEnum() const { return type.getEnum(); }
    final bool isKnown() { return !isImport && type.isKnown(); }

    bool exactlyMatches(Type other)      { assert(false); }
    bool canImplicitlyCastTo(Type other) { assert(false); }
    LLVMTypeRef getLLVMType()            { assert(false); }
    string prettyString()                { assert(false); }
    //=======================================================================================

    string getMangledName() {
        return .mangle(this);
    }
    /// Get to the defined type. This might not be type if the rhs is also a Define
    Type getRootType() {
        if(type.isA!Define) return type.as!Define.getRootType;
        return type;
    }

    //=======================================================================================
    override string toString() {
        string val = "%s".format(getType);
        string imp = isImport ? " (IMPORT)" : "";
        return "Define[refs=%s] %s = %s%s".format(numRefs, name, val, imp);
    }
}
