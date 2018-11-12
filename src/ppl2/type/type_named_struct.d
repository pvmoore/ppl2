module ppl2.type.type_named_struct;

import ppl2.internal;
import common : contains;
///
///
///
final class NamedStruct : AnonStruct {
private:
    string _uniqueName;
public:
    string name;
    string moduleName;
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
    override NodeID id() const { return NodeID.NAMED_STRUCT; }
    override bool isKnown() { return true; }

/// Type interface
    override int getEnum() const { return Type.NAMED_STRUCT; }

    override bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type
        if(!other.isNamedStruct) return false;

        auto right = other.getNamedStruct;

        return name==right.name;
    }
    override bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isNamedStruct) return false;

        auto right = other.getNamedStruct;

        return name==right.name;
    }
    override LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = struct_(getUniqueName());
        }
        return _llvmType;
    }
    //========================================================================================
    Variable[] getStaticVariables() {
        return children[]
                   .filter!(it=>it.id==NodeID.VARIABLE)
                   .map!(it=>cast(Variable)it)
                   .filter!(it=>it.isStatic)
                   .array;
    }
    Variable getStaticVariable(string name) {
        return getStaticVariables()
            .filter!(it=>it.name==name)
            .frontOrNull!Variable;
    }
    ////========================================================================================
    Function[] getStaticFunctions() {
        return children[]
                   .filter!(it=>it.id==NodeID.FUNCTION)
                   .map!(it=>cast(Function)it)
                   .filter!(it=>it.isStatic)
                   .array;
    }
    Function[] getStaticFunctions(string name) {
        return getStaticFunctions()
                    .filter!(it=>name==it.name)
                    .array;
    }
    //========================================================================================
    Function[] getMemberFunctions() {
        return children[]
                   .filter!(it=>it.id==NodeID.FUNCTION)
                   .map!(it=>cast(Function)it)
                   .filter!(it=>it.isStatic==false)
                   .array;
    }
    Function[] getMemberFunctions(string name) {
        return getMemberFunctions()
                    .filter!(it=>name==it.name)
                    .array;
    }
    int getMemberIndex(Function var) {
        foreach(int i, v; getMemberFunctions()) {
            if(var is v) return i;
        }
        return -1;
    }
    override int getMemberIndex(Variable var) {
        return super.getMemberIndex(var);
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
            _uniqueName = getModule().buildState.mangler.mangle(this);
        }
        return _uniqueName;
    }
    //========================================================================================
    override string toString() {
        return getUniqueName();
    }
}