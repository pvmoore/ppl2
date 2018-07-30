module ppl2.ast.stmt_function;

import ppl2.internal;
import common : contains;
///
///  function::= identifier "=" [template params] function_literal
///
final class Function : Statement {
private:
    string _uniqueName;
public:
    string name;
    string moduleName;      /// canonical name of module (!=this.getModule.canonicalName if isImport)
    int moduleNID;          /// nid of module (!=this.getModule.nid if isImport)
    Access access = Access.PUBLIC;

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

        /// Return type of body
        return getBody().getType;
    }
///
    bool isStructMember() const {
        return getContainer().id==NodeID.ANON_STRUCT;
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
        assert(!isImport, "Function %s is import".format(name));
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
        string acc = "[%s] ".format(access);
        string loc = isExtern ? "EXTERN" :
                     isImport ? "IMPORT" :
                     isInner ? "INNER" :
                     isGlobal ? "GLOBAL" : "STRUCT";
        string s;
        if(isTemplateBlueprint()) {
            s ~= "<" ~ blueprint.paramNames.join(",") ~ "> ";
        }
        return "'%s' %s Function[refs=%s,%s] (%s) %s".format(name, s, numRefs, numExternalRefs, loc, acc);
    }
}
