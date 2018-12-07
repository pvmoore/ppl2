module ppl2.type.Tuple;

import ppl2.internal;
///
///
///
final class Tuple : ASTNode, Type, Container {
private:
    LLVMTypeRef _llvmType;
    int _size      = -1;
    int _alignment = -1;
public:
/// ASTNode interface
    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.TUPLE; }
    override Type getType()    { return this; }

    /// Tuples are all @pack(false)
    int getSize() {
        if(_size==-1) {
            _size = calculateAggregateSize(memberVariableTypes());
        }
        return _size;
    }
    /// Alignment is alignment of largest member
    int getAlignment() {
        if(_alignment==-1) {
            if(numMemberVariables==0) {
                /// An empty tuple has align of 1
                _alignment = 1;
            } else {
                import std.algorithm.searching;
                _alignment = memberVariableTypes().map!(it=>it.alignment).maxElement;
            }
        }
        return _alignment;
    }

/// Type interface
    int category() const { return Type.TUPLE; }
    bool isKnown() { return memberVariableTypes().all!(it=>it.isKnown); }
    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;

        /// Size must be the same
        if(this.size != other.size) return false;

        /// Now check the base type
        if(!other.isTuple) return false;

        auto right = other.getTuple;
        return .exactlyMatch(memberVariableTypes(), right.memberVariableTypes);
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;

        /// Size must be the same
        if(this.size != other.size) return false;

        /// Now check the base type
        if(!other.isTuple) return false;

        auto right = other.getTuple;

        /// Types must match exactly
        return .exactlyMatch(memberVariableTypes(), right.memberVariableTypes);
    }
    LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = .struct_(getLLVMTypes(), true);
        }
        return _llvmType;
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
    int getMemberIndex(Variable var) {
        if(!var) return -1;
        assert(!var.isStatic);
        foreach(int i, v; getMemberVariables()) {
            if(var is v) return i;
        }
        return -1;
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
    //===============================================================
    override string toString() {
        return "[%s]".format(memberVariableTypes().toString());
    }
}