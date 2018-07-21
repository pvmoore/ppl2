module ppl2.type.define;

import ppl2.internal;

class Define : Statement, Type {
    string name;
    string moduleName;
    bool isImport;
    int numRefs;
    Type type;

    /// template proxy
    Type templateProxyType;     /// Define or NamedStruct
    Type[] templateProxyParams;

    this() {
        type = TYPE_UNKNOWN;
    }

    bool isTemplateProxy() { return templateProxyType !is null; }

/// ASTNode
    override bool isResolved() {
        if(isKnown) return true;

        auto ns = type.getNamedStruct;
        return ns && ns.isTemplate;

        //if(isImport) return true;
        //return type.isKnown;
    }
    final override NodeID id() const { return NodeID.DEFINE; }
    override Type getType() { return type; }
/// Type
    final int getEnum() const { return type.getEnum(); }
    final bool isKnown() {
        return !type.isDefine && type.isKnown;
        //if(type.isDefine) return false;
        //if(type.isKnown) return true;
        //auto ns = type.getNamedStruct;
        //return ns && ns.isTemplate;
    }

    bool exactlyMatches(Type other)      { assert(false); }
    bool canImplicitlyCastTo(Type other) { assert(false); }
    LLVMTypeRef getLLVMType()            { assert(false); }
    string prettyString()                { assert(false); }
    //=======================================================================================

    string getMangledName() {
        return .mangle(this);
    }
    /// Get to the defined type. This might not be type if the rhs is also a Define
    //Type getRootType() {
    //    if(type.isA!Define) return type.as!Define.getRootType;
    //    return type;
    //}

    //=======================================================================================
    override string toString() {
        string val = "%s".format(getType);
        string imp = isImport ? " (IMPORT)" : "";
        return "Define[refs=%s] name=%s (type=%s)%s".format(numRefs, name, val, imp);
    }
}
