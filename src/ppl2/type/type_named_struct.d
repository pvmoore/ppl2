module ppl2.type.type_named_struct;

import ppl2.internal;
import common : contains;
///
///
///
final class NamedStruct : ASTNode, Type {
private:
    string _uniqueName;
    LLVMTypeRef _llvmType;
public:
    string name;
    string moduleName;
    AnonStruct type;
    int numRefs;

/// Template stuff
    string[] templateParamNames;
    Token[] tokens;
    bool isTemplateBlueprint() { return templateParamNames.length > 0; }
    bool isTemplateInstance()  { return name.contains('<'); }
/// end of template stuff

/// ASTNode interface
    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.NAMED_STRUCT; }
    override Type getType() { return this; }

/// Type interface
    int getEnum() const { return Type.NAMED_STRUCT; }
    bool isKnown() { return type !is null; } //  && type.isKnown

    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type
        if(!other.isNamedStruct) return false;

        auto right = other.getNamedStruct;

        return name==right.name;
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isNamedStruct) return false;

        auto right = other.getNamedStruct;

        return name==right.name;
    }
    LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = struct_(getUniqueName());
        }
        return _llvmType;
    }
    string prettyString() {
        return getUniqueName();
    }
    //========================================================================================
    bool isAtModuleScope() {
        return parent.isModule;
    }
    string getUniqueName() {
        if(!_uniqueName) {
            _uniqueName = mangle(this);
        }
        return _uniqueName;
    }
    //========================================================================================
    override string description() {
        return "NamedStruct[refs=%s] %s".format(numRefs, toString());
    }
    override string toString() {
        string s;
        if(isTemplateBlueprint()) {
            s ~= "<" ~ templateParamNames.join(",") ~ "> ";
        }
        return "%s%s:%s%s".format(s, name, getUniqueName, isKnown ? "":"?");
    }
}