module ppl2.type.Alias;

import ppl2.internal;

final class Alias : Statement, Type {
    string name;
    string moduleName;
    int moduleNID;
    bool isImport;
    int numRefs;
    Type type;
    Category cat = Category.STANDARD;

    enum Category {
        STANDARD,       /// alias a = type
        TEMPLATE_PROXY, /// s<type>
        TYPEOF_EXPR     /// #typeof ( expr )
    }

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
    final int category() const { return type.category(); }
    final bool isKnown()       { return false; }

    bool exactlyMatches(Type other)      { assert(false); }
    bool canImplicitlyCastTo(Type other) { assert(false); }
    LLVMTypeRef getLLVMType()            { assert(false); }
    //=======================================================================================
    override string toString() {
        return "alias of %s".format(type);
    }
}
