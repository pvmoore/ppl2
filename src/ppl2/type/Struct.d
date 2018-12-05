module ppl2.type.Struct;

import ppl2.internal;

final class Struct : ASTNode, Type, Container {
protected:
    LLVMTypeRef _llvmType;
    int _size      = -1;
    int _alignment = -1;
    bool _isPacked = false;
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
    bool isTemplateInstance()  {
        import common : contains;
        return name.contains('<');
    }
/// end of template stuff

    int getSize() {
        if(_size==-1) {
            auto pack = attributes.get!PackAttribute;
            if(pack) {
                _isPacked = pack.value;
            }
            if(_isPacked) {
                _size = memberVariableTypes().map!(it=>it.size).sum;
            } else {
                _size = calculateAggregateSize(memberVariableTypes());
            }
        }
        return _size;
    }
    /// Alignment is alignment of largest member
    int getAlignment() {
        if(_alignment==-1) {
            if(numMemberVariables==0) {
                /// An empty struct has align of 1
                _alignment = 1;
            } else {
                import std.algorithm.searching;
                _alignment = memberVariableTypes().map!(it=>it.alignment).maxElement;
            }
        }
        return _alignment;
    }
    bool isPacked() {
        if(_size==-1) getSize();
        return _isPacked;
    }

/// ASTNode interface
    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.STRUCT; }
    override Type getType()    { return this; }

/// Type interface
    override int category() const { return Type.STRUCT; }
    override bool isKnown() { return true; }

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
    ///========================================================================================
    int numMemberVariables() {
        return getMemberVariables().length.as!int;
    }
    Variable[] getMemberVariables() {
        return children[].filter!(it=>it.id==NodeID.VARIABLE)
                .map!(it=>cast(Variable)it)
                .filter!(it=>it.isStatic==false)
                .array;
    }
    Variable getMemberVariable(string name) {
        return getMemberVariables()
                .filter!(it=>name==it.name)
                .frontOrNull!Variable;
    }
    Variable getMemberVariable(int index) {
        return getMemberVariables()[index];
    }
    Type[] memberVariableTypes() {
        return getMemberVariables()
                .map!(it=>(cast(Variable)it).type)
                .array;
    }
    LLVMTypeRef[] getLLVMTypes() {
        return memberVariableTypes()
                .map!(it=>it.getLLVMType())
                .array;
    }
    ///========================================================================================
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
        auto array = new DynamicArray!Function;
        recursiveCollect!Function(array, f=>f.isInner);
        return array[];
    }
    ///
    /// Return true if there are Composites at root level which signifies
    /// that a template function has just been added
    ///
    bool containsComposites() {
        foreach(ch; children) {
            if(ch.isComposite) return true;
        }
        return false;
    }
    int getMemberIndex(Function var) {
        foreach(int i, v; getMemberFunctions()) {
            if(var is v) return i;
        }
        return -1;
    }
    int getMemberIndex(Variable var) {
        assert(!var.isStatic);
        foreach(int i, v; getMemberVariables()) {
            if(var is v) return i;
        }
        return -1;
    }
    ///========================================================================================
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