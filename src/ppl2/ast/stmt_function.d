module ppl2.ast.stmt_function;

import ppl2.internal;
/**
 *  function::= identifier "=" function_literal
 */
final class Function : Statement, Callable {
    string name;
    Type externType;          /// for extern functions only
    string moduleName;
    bool isImport;
    bool isExtern;
    int numRefs;

    this() {
        this.externType = TYPE_UNKNOWN;
    }

    override bool isResolved() { return getType.isKnown; }
    override NodeID id() const { return NodeID.FUNCTION; }
    override Type getType() {
        if(isExtern) return externType;
        // Return type of body
        return getBody().getType;
    }

    bool isLocal() const {
        return getContainer().id()==NodeID.LITERAL_FUNCTION;
    }
    bool isStructMember() const {
        return getContainer().id()==NodeID.ANON_STRUCT;
    }
    bool isGlobal() const {
        return parent.isModule;
    }
    bool isClosure() {
        return parent.isLiteralFunction;
    }
    bool isDefaultConstructor() {
        if(isImport || isExtern) return false;
        if(name!="new") return false;
        return args.numArgs==0 || (args.numArgs==1 && args.argNames[0]=="this");
    }

    string getName() { return name; }
    Arguments args() { return isExtern ? null : getBody().args(); }

    LiteralFunction getBody() {
        assert(!isExtern, "Function %s is extern".format(name));
        assert(hasChildren(), "Function %s has no body".format(name));

        foreach(ch; children) {
            if(ch.isA!LiteralFunction) return ch.as!LiteralFunction;
        }
        assert(false, "Non extern function %s has no LiteralFunction".format(name));
    }

    string getMangledName() {
        return .mangle(this);
    }

    override string toString() {
        string loc = isExtern ? "EXTERN" :
                     isImport ? "IMPORT" :
                     isLocal ? "LOCAL" :
                     isGlobal ? "GLOBAL" : "STRUCT";
        return "'%s' Function[refs=%s] (%s)".format(name, numRefs, loc);
    }
}