module ppl2.type.Struct;

import ppl2.internal;

final class Struct : Tuple {
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
    bool isTemplateInstance()  {
        import common : contains;
        return name.contains('<');
    }
/// end of template stuff

/// ASTNode interface
    override NodeID id() const { return NodeID.STRUCT; }
    override bool isKnown() { return true; }

/// Type interface
    override int category() const { return Type.STRUCT; }

    override bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type
        if(!other.isStruct) return false;

        auto right = other.getStruct;

        return name==right.name;
    }
    override bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isStruct) return false;

        auto right = other.getStruct;

        return name==right.name;
    }
    override LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = struct_(name);
        }
        return _llvmType;
    }
    ///========================================================================================
    Enum getInnerEnum(string name) {
        return children[]
                .filter!(it=>it.id==NodeID.ENUM && it.as!Enum.name==name)
                .frontOrNull!Enum;
    }
    Struct getInnerStruct(string name) {
        return children[]
                .filter!(it=>it.id==NodeID.STRUCT && it.as!Struct.name==name)
                .frontOrNull!Struct;
    }
    ///========================================================================================
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
    ///========================================================================================
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
    ///========================================================================================
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
    bool hasDefaultConstructor() {
        return getDefaultConstructor() !is null;
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
    int getMemberIndex(Function var) {
        foreach(int i, v; getMemberFunctions()) {
            if(var is v) return i;
        }
        return -1;
    }
    override int getMemberIndex(Variable var) {
        return super.getMemberIndex(var);
    }
    ///========================================================================================
    bool isAtModuleScope() {
        return parent.isModule;
    }
    bool hasOperatorOverload(Operator op) {
        string fname = "operator";
        if(op==Operator.NEG) {
            fname ~= " neg";
        } else {
            fname ~= op.value;
        }
        return getMemberFunctions(fname).length > 0;
    }
    //========================================================================================
    override string toString() {
        return name;
    }
}