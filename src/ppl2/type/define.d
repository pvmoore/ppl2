module ppl2.type.alias_;

import ppl2.internal;

final class Alias : Statement, Type {
    string name;
    string moduleName;
    int moduleNID;
    bool isImport;
    int numRefs;
    Type type;

/// template stuff
    Type templateProxyType;     /// Alias or NamedStruct
    Type[] templateProxyParams;

    this() {
        type = TYPE_UNKNOWN;
    }

    bool isTemplateProxy() { return templateProxyType !is null; }

/// ASTNode
    override bool isResolved() { return false; }
    override NodeID id() const { return NodeID.ALIAS; }
    override Type getType()    { return type; }

/// Type
    final int getEnum() const { return type.getEnum(); }
    final bool isKnown()      { return false; }

    bool exactlyMatches(Type other)      { assert(false); }
    bool canImplicitlyCastTo(Type other) { assert(false); }
    LLVMTypeRef getLLVMType()            { assert(false); }
    string prettyString()                { return "Alias %s=%s".format(name,type.prettyString); }
    //=======================================================================================
    override string toString() {
        string val = "%s".format(getType.prettyString);
        string imp = isImport ? " (IMPORT)" : "";
        return "Alias[refs=%s] name=%s (type=%s)%s".format(numRefs, name, val, imp);
    }
}
