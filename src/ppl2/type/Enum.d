module ppl2.type.Enum;

import ppl2.internal;

///
/// Enum
///     [] children are all Variables
final class Enum : ASTNode, Type {
private:
    LLVMTypeRef _llvmType;
public:
    string name;
    string moduleName;
    Type elementType;
    Access access = Access.PUBLIC;
    int numRefs;

    this() {
        this.elementType = TYPE_INT;
    }

/// ASTNode interface
    override bool isResolved() {
        return elementType.isKnown && allMembersAreResolved();
    }
    override NodeID id() const { return NodeID.ENUM; }
    override Type getType()    { return this; }

/// Type interface
    int category() const { return Type.ENUM; }
    bool isKnown()       { return true; }

    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        if(!other.isEnum) return false;

        auto right = other.getEnum;

        return name==right.name;
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        if(!other.isEnum) return false;

        auto right = other.getEnum;

        return name==right.name;
    }
    LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = struct_(name);
        }
        return _llvmType;
    }
/// end of Type interface

    EnumMember[] members() {
        return children[].as!(EnumMember[]);
    }
    EnumMember member(string name) {
        return members().filter!(it=>it.name==name).frontOrNull!EnumMember;
    }

    bool allMembersAreResolved() {
        return members().all!(it=>it.isResolved);
    }
    Expression firstValue() {
        assert(hasChildren);
        return first().as!EnumMember;
    }

    override string toString() {
        return name;
    }
}
final class EnumMember : Expression {
    string name;
    Enum type;
    //bool isCompilerGenerated;   /// true if we created this as the result of a binary operation for eg

    override bool isResolved()    { return hasChildren && expr().isResolved; }
    override NodeID id() const    { return NodeID.ENUM_MEMBER; }
    override bool isConst()       { return expr().isConst; }
    override int priority() const { return 15; }
    override Type getType()       { return type; }

    Expression expr() { return first().as!Expression; }

    override string toString() {
        return "EnumMember %s (type=%s)".format(name, type);
    }
}
/// EnumMemberValue
///     expr
final class EnumMemberValue : Expression {
    Enum enum_;

    override bool isResolved()    { return hasChildren && expr().isResolved; }
    override NodeID id() const    { return NodeID.ENUM_MEMBER_VALUE; }
    override bool isConst()       { return expr().isConst; }
    override int priority() const { return 15; }
    override Type getType()       { return enum_.elementType; }

    Expression expr() { return first().as!Expression; }

    override string toString() {
        return "EnumMemberValue %s".format(getType);
    }
}