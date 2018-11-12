module ppl2.type.type_anon_struct;

import ppl2.internal;
///
///
///
class AnonStruct : ASTNode, Type, Container {
protected:
    LLVMTypeRef _llvmType;
public:
/// ASTNode interface
    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.ANON_STRUCT; }
    override Type getType() { return this; }

/// Type interface
    int getEnum() const { return Type.ANON_STRUCT; }
    bool isKnown() {
        return memberVariableTypes().all!(it=>it.isKnown);
    }
    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;

        /// Size must be the same
        if(this.size != other.size) return false;

        /// Now check the base type
        if(!other.isAnonStruct) return false;

        auto right = other.getAnonStruct;
        return .exactlyMatch(memberVariableTypes(), right.memberVariableTypes);
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;

        /// Size must be the same
        if(this.size != other.size) return false;

        /// Now check the base type
        if(!other.isAnonStruct) return false;

        auto right = other.getAnonStruct;

        /// Types must match exactly
        return .exactlyMatch(memberVariableTypes(), right.memberVariableTypes);
    }
    LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = .struct_(getLLVMTypes(), true);
        }
        return _llvmType;
    }
/// end of Type interface

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
    int getMemberIndex(Variable var) {
        assert(!var.isStatic);
        foreach(int i, v; getMemberVariables()) {
            if(var is v) return i;
        }
        return -1;
    }
    //===============================================================
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
    //===============================================================
    override string toString() {
        return "[%s]".format(memberVariableTypes().toString());
    }
}