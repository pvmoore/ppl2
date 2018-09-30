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
    Access access = Access.PUBLIC;

    /// Set to true if no body is specified.
    /// A full definition is expected later in the file.
    /// eg.
    /// struct Gold // this is declaration only
    /// // ...
    /// struct Gold = [ ... ]
    bool isDeclarationOnly;

/// Template stuff
    TemplateBlueprint blueprint;
    bool isTemplateBlueprint() { return blueprint !is null; }
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
    Variable[] getStaticVariables() {
        return type.children[]
                   .filter!(it=>it.id==NodeID.VARIABLE)
                   .map!(it=>cast(Variable)it)
                   .filter!(it=>it.isStatic)
                   .array;
    }
    Variable getStaticVariable(string name) {
        auto r = getStaticVariables().filter!(it=>it.name==name).takeOne;
        return r.empty ? null : r.front;
    }
    ////========================================================================================
    Function[] getStaticFunctions() {
        return type.children[]
                   .filter!(it=>it.id==NodeID.FUNCTION)
                   .map!(it=>cast(Function)it)
                   .filter!(it=>it.isStatic)
                   .array;
    }
    Function[] getStaticFunctions(string name) {
        return getStaticFunctions().filter!(it=>name==it.name).array;
    }
    //========================================================================================
    Function[] getMemberFunctions() {
        return type.children[].filter!(it=>it.id==NodeID.FUNCTION)
                         .map!(it=>cast(Function)it)
                         .filter!(it=>it.isStatic==false)
                         .array;
    }
    Function[] getMemberFunctions(string name) {
        return getMemberFunctions().filter!(it=>name==it.name).array;
    }
    int getMemberIndex(Function var) {
        foreach(int i, v; getMemberFunctions()) {
            if(var is v) return i;
        }
        return -1;
    }
    bool hasDefaultConstructor() {
        return getDefaultConstructor() !is null;
    }
    bool hasOperatorOverload(Operator op) {
        string name = "operator";
        if(op==Operator.NEG) {
            name ~= " neg";
        } else {
            name ~= op.value;
        }
        return getMemberFunctions(name).length > 0;
    }
    Function getDefaultConstructor() {
        foreach(f; getConstructors()) {
            if(f.isDefaultConstructor) return f;
        }
        return null;
    }
    Function[] getConstructors() {
        return getMemberFunctions("new");
    }
    Function[] getInnerFunctions() {
        auto array = new Array!Function;
        recursiveCollect!Function(array, f=>f.isInner);
        return array[];
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
        string acc = "[%s]".format(access);
        string s;
        if(isTemplateBlueprint()) {
            s ~= "<" ~ blueprint.paramNames.join(",") ~ "> ";
        }
        return "%s%s%s %s".format(s, getUniqueName, isKnown ? "":"?", acc);
    }
}