module ppl2.type.type_anon_struct;

import ppl2.internal;
///
///
///
final class AnonStruct : ASTNode, Type, Container {
/// ASTNode interface
    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.ANON_STRUCT; }
    override Type getType() { return this; }

/// Type interface
    int getEnum() const { return Type.ANON_STRUCT; }
    bool isKnown() { return memberVariableTypes().all!(it=>it.isKnown); }
    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type
        if(!other.isAnonStruct) return false;

        auto right = other.getAnonStruct;
        return .exactlyMatch(memberVariableTypes(), right.memberVariableTypes);
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isAnonStruct) return false;

        auto right = other.getAnonStruct;

        /// Types implicitly match
        return .canImplicitlyCastTo(memberVariableTypes(), right.memberVariableTypes);
    }
    Expression defaultInitialiser() {
        assert(isKnown);

        auto lit = makeNode!LiteralStruct(this);
        lit.type = this;

        /// Create default assignment for each member type
        foreach(v; getMemberVariables()) {
            lit.addToEnd(v.type.defaultInitialiser());
        }

        return lit;
    }
    //========================================================================================
    bool isNamed() {
        return parent && parent.isNamedStruct;
    }
    string getName() {
        if(isNamed()) {
            return parent.as!NamedStruct.name;
        }
        return null;
    }

    /// Extract this template
    AnonStruct extract(Type[] types) {
        assert(false, "extract struct template");
    }

    Variable[] getMemberVariables() {
        return cast(Variable[])
            children[].filter!(it=>cast(Variable)it !is null)
                      .array;
    }
    int numMemberVariables() {
        return getMemberVariables().length.as!int;
    }
    Variable getMemberVariable(string name) {
        auto r = getMemberVariables().filter!(it=>name==it.name).takeOne;
        return r.empty ? null : r.front;
    }
    Variable getMemberVariable(int index) {
        return getMemberVariables()[index];
    }
    Function[] getMemberFunctions() {
        return cast(Function[])
            children[].filter!(it=>cast(Function)it !is null)
                      .array;
    }
    Function[] getMemberFunctions(string name) {
        return getMemberFunctions().filter!(it=>name==it.name).array;
    }
    int getMemberIndex(Variable var) {
        foreach(int i, v; getMemberVariables()) {
            if(var is v) return i;
        }
        return -1;
    }
    int getMemberIndex(Function var) {
        foreach(int i, v; getMemberFunctions()) {
            if(var is v) return i;
        }
        return -1;
    }
    //===============================================================
    Type[] memberVariableTypes() {
        return children[].filter!(it=>it.id() == NodeID.VARIABLE)
                         .map!(it=>(cast(Variable)it).type)
                         .array;
    }
    //===============================================================
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
    //===============================================================
    override string toString() {
        return "AnonStruct %s".format(memberVariableTypes());
    }
}