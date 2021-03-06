module ppl2.ast.stmt_function;

import ppl2.internal;
import common : contains;
///
///  function::= identifier "=" [template params] function_literal
///
final class Function : Statement {
private:
    string _mangledName;
public:
    string name;
    string moduleName;      /// canonical name of module (!=this.getModule.canonicalName if isImport)
    Access access = Access.PUBLIC;
    bool isStatic;

    Operator op = Operator.NOTHING; /// Set if this is an operator overload

    Type externType;        /// for extern functions only
    bool isImport;          /// true if this is just a proxy for an imported function
    bool isExtern;

    int numRefs;            /// Total calls to this function
    int numExternalRefs;    /// Num calls to this function from outside the module
    LLVMValueRef llvmValue;

/// Template stuff
    TemplateBlueprint blueprint;
    bool isTemplateBlueprint() { return blueprint !is null; }
    bool isTemplateInstance()  { return name.contains('<'); }
/// end of template stuff

    this() {
        this.externType = TYPE_UNKNOWN;
    }
/// ASTNode
    override bool isResolved() { return getType.isKnown; }
    override NodeID id() const { return NodeID.FUNCTION; }
    override Type getType() {
        if(isExtern) return externType;
        if(isTemplateBlueprint) return TYPE_UNKNOWN;
        /// This should only happen if we are incrementally building
        if(!hasChildren()) return TYPE_VOID;

        /// Return type of body
        return getBody().getType;
    }
///
    bool isProgramEntry() {
        return "main"==name || "WinMain"==name;
    }
    bool isStructMember() const {
        return getContainer().id==NodeID.STRUCT;
    }
    bool isGlobal() const {
        return getContainer().id==NodeID.MODULE;
    }
    bool isInner() {
        return getContainer().id==NodeID.LITERAL_FUNCTION;
    }
    bool isDefaultConstructor() {
        if(isImport || isExtern) return false;
        if(name!="new") return false;
        return params().numParams==0 || (params().numParams==1 && params().paramNames[0]=="this");
    }
    bool isOperatorOverload() {
        return op != Operator.NOTHING;
    }

    Parameters params() {
        return isExtern ? null : getBody().params();
    }
    Struct getStruct() {
        assert(isStructMember());
        return parent.as!Struct;
    }
    LiteralFunction getBody() {
        assert(!isExtern, "Function %s is extern".format(name));
        assert(!isImport, "Function %s is import".format(name));
        assert(hasChildren(), "Function %s has no body".format(name));

        foreach(ch; children) {
            if(ch.isA!LiteralFunction) return ch.as!LiteralFunction;
        }
        assert(false, "Non extern function %s has no LiteralFunction".format(name));
    }
    void resetName(string newName) {
        this.name = newName;
        this._mangledName = null;
    }
    string getMangledName() {
        if(!_mangledName) {
            _mangledName = getModule().buildState.mangler.mangle(this);
        }
        return _mangledName;
    }
    LLVMCallConv getCallingConvention() {
        if(isExtern) return LLVMCallConv.LLVMCCallConv;
        if(isProgramEntry) return LLVMCallConv.LLVMCCallConv;
        return LLVMCallConv.LLVMFastCallConv;
    }

    override string toString() {
        string mod = isStatic ? "static " : "";

        string loc = isExtern ? "EXTERN" :
                     isImport ? "IMPORT" :
                     isInner ? "INNER" :
                     isGlobal ? "GLOBAL" : "STRUCT";
        string s;
        if(isTemplateBlueprint()) {
            s ~= "<" ~ blueprint.paramNames.join(",") ~ "> ";
        }
        return "'%s' %s%sFunction[refs=%s,%s] %s %s".format(name, mod, s, numRefs, numExternalRefs, loc, access);
    }
}
