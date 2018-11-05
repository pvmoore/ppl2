module ppl2.ast.stmt_variable;

import ppl2.internal;

///
/// variable ::= type identifier [ "=" expression ]
///
/// Possible children: 0, 1 or 2:
///
/// Variable
///     Initialiser
///
final class Variable : Statement {
    Type type;
    string name;
    bool isConst;
    bool isImplicit;    /// true if this is a "var"
    bool isStatic;
    int numRefs;
    Access access = Access.PUBLIC;

    LLVMValueRef llvmValue;

    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.VARIABLE; }
    override Type getType()    { return type; }

    bool isLocal() const {
        return parent.isLiteralFunction || parent.isIf || parent.isLoop;
        //return getContainer().id()==NodeID.LITERAL_FUNCTION;
    }
    bool isNamedStructMember() {
        return !isStatic && parent.isAnonStruct && parent.as!AnonStruct.isNamed;
    }
    bool isAnonStructMember() {
        return !isStatic && parent.isAnonStruct && !parent.as!AnonStruct.isNamed;
    }
    bool isStructMember() const {
        return !isStatic && parent.isAnonStruct;
    }
    bool isGlobal() const {
        return parent.isModule;
    }
    bool isParameter() {
        return parent.isA!Parameters;
    }
    bool isFunctionPtr() {
        return type.isKnown && type.isFunction;
    }
    bool hasInitialiser() {
        return children[].any!(it=>it.isInitialiser);
    }
    Initialiser initialiser() {
        assert(numChildren>0);
        foreach(ch; children) {
            if(ch.isInitialiser) return ch.as!Initialiser;
        }
        assert(false, "Where is our Initialiser?");
    }
    Type initialiserType() {
        return hasInitialiser() ? initialiser().getType() : null;
    }

    AnonStruct getAnonStruct() {
        assert(isAnonStructMember);
        return parent.as!AnonStruct;
    }
    NamedStruct getNamedStruct() {
        assert(isNamedStructMember());
        return parent.parent.as!NamedStruct;
    }
    Function getFunction() {
        assert(isParameter());
        auto bd = getAncestor!LiteralFunction();
        assert(bd);
        return bd.getFunction();
    }

    void setType(Type t) {
        this.type = t;

        if(first().isA!Type) {
            removeAt(0);
        }
    }

    override string toString() {
        string mod = isStatic ? "static " : "";
        mod ~= isConst ? "const ":"";

        string loc = isParameter ? "PARAM" :
                     isLocal ? "LOCAL" :
                     isGlobal ? "GLOBAL" : "STRUCT";

        if(name) {
            return "'%s' Variable[refs=%s] (type=%s%s) %s %s".format(name, numRefs, mod, type, loc, access);
        }
        return "Variable[refs=%s] (type=%s%s) %s %s".format(numRefs, mod, type, loc, access);
    }
}