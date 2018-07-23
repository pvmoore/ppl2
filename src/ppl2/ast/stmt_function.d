module ppl2.ast.stmt_function;

import ppl2.internal;
///
///  function::= identifier "=" [template params] function_literal
///
final class Function : Statement {
private:
    string _uniqueName;
public:
    string name;
    string moduleName;

    Type externType;        /// for extern functions only
    bool isImport;          /// true if this is just a proxy for an imported function
    bool isExtern;

    int numRefs;            /// Total calls to this function
    int numExternalRefs;    /// Num calls to this function from outside the module
    LLVMValueRef llvmValue;

/// Template stuff
    string[] templateParamNames;
    Token[] tokens;
    bool isTemplate() const { return templateParamNames.length > 0; }
/// end of template stuff

    this() {
        this.externType = TYPE_UNKNOWN;
    }
/// ASTNode
    override bool isResolved() { return getType.isKnown; }
    override NodeID id() const { return NodeID.FUNCTION; }
    override Type getType() {
        if(isExtern) return externType;
        if(isTemplate) return TYPE_UNKNOWN;

        /// Return type of body
        return getBody().getType;
    }
///
    bool isLocal() const {
        return getContainer().id()==NodeID.LITERAL_FUNCTION;
    }
    bool isStructMember() const {
        return parent.id()==NodeID.ANON_STRUCT;
    }
    bool isGlobal() const {
        return getContainer().id()==NodeID.MODULE;
    }
    bool isDefaultConstructor() {
        if(isImport || isExtern) return false;
        if(name!="new") return false;
        return params().numParams==0 || (params().numParams==1 && params().paramNames[0]=="this");
    }

    Parameters params() { return isExtern ? null : getBody().params(); }
    AnonStruct getStruct() {
        assert(isStructMember());
        return parent.as!AnonStruct;
    }

    bool isProgramEntry() {
        return "main"==name && moduleName == g_mainModuleCanonicalName;
    }
    LiteralFunction getBody() {
        assert(!isExtern, "Function %s is extern".format(name));
        assert(hasChildren(), "Function %s has no body".format(name));

        foreach(ch; children) {
            if(ch.isA!LiteralFunction) return ch.as!LiteralFunction;
        }
        assert(false, "Non extern function %s has no LiteralFunction".format(name));
    }
    string getUniqueName() {
        if(!_uniqueName) {
            _uniqueName = .mangle(this);
        }
        return _uniqueName;
    }
    LLVMCallConv getCallingConvention() {
        if(isExtern) return LLVMCallConv.LLVMCCallConv;
        if(isProgramEntry) return LLVMCallConv.LLVMCCallConv;
        return LLVMCallConv.LLVMFastCallConv;
    }

    override string toString() {
        string loc = isExtern ? "EXTERN" :
                     isImport ? "IMPORT" :
                     isLocal ? "LOCAL" :
                     isGlobal ? "GLOBAL" : "STRUCT";
        string s;
        if(isTemplate()) {
            s ~= "<" ~ templateParamNames.join(",") ~ "> ";
        }
        return "'%s' %s Function[refs=%s,%s] (%s)".format(name, s, numRefs, numExternalRefs, loc);
    }
}
