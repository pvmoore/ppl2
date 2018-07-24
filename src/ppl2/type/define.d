module ppl2.type.define;

import ppl2.internal;

final class Define : Statement, Type {
    string name;
    string moduleName;
    bool isImport;
    int numRefs;
    Type type;

/// template stuff
    Type templateProxyType;     /// Define or NamedStruct
    Type[] templateProxyParams;

    this() {
        type = TYPE_UNKNOWN;
    }

    bool isTemplateProxy() { return templateProxyType !is null; }

/// ASTNode
    override bool isResolved() { return false; }
    final override NodeID id() const { return NodeID.DEFINE; }
    override Type getType() { return type; }
/// Type
    final int getEnum() const { return type.getEnum(); }
    final bool isKnown() { return false; }

    bool exactlyMatches(Type other)      { assert(false); }
    bool canImplicitlyCastTo(Type other) { assert(false); }
    LLVMTypeRef getLLVMType()            { assert(false); }
    string prettyString()                { assert(false); }
    //=======================================================================================
    override string toString() {
        string val = "%s".format(getType);
        string imp = isImport ? " (IMPORT)" : "";
        return "Define[refs=%s] name=%s (type=%s)%s".format(numRefs, name, val, imp);
    }
}
