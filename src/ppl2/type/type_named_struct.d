module ppl2.type.type_named_struct;

import ppl2.internal;

///
///
///
final class NamedStruct : ASTNode, Type {
private:
    string _uniqueName;
public:
    string name;
    AnonStruct type;
    int numRefs;

    string[] templateArgNames;  /// if isTemplate==true
    Token[] tokens;             /// if isTemplate==true

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
        return .exactlyMatch(type.memberVariableTypes(), right.type.memberVariableTypes);
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isNamedStruct) return false;

        auto right = other.getNamedStruct;

        /// Types implicitly match
        return .canImplicitlyCastTo(type.memberVariableTypes(), right.type.memberVariableTypes);
    }
    Expression defaultInitialiser() {
        assert(isKnown);

        /// call default constructor
        /// return this*
        auto composite = makeNode!CompositeExpression();
        auto module_   = getModule();
        auto builder   = module_.nodeBuilder;

        /// Create a Variable only if we really have to
        auto var = builder.variable(module_.makeTemporary(name), this);

        auto id        = builder.identifier(var.name);
        auto thisPtr   = builder.addressOf(id);

        auto structId = builder.identifier(id.name);
        auto call     = builder.call("new", null);
        call.addToEnd(thisPtr);

        auto dot = builder.dot(structId, call);
        auto val = builder.valueOf(dot);

        var.addToEnd(val);

        composite.addToEnd(var);

        return composite;
    }
    LLVMTypeRef getLLVMType() {
        return type.getLLVMType();
    }
    //========================================================================================
    bool isTemplate() const { return templateArgNames.length > 0; }

    string getUniqueName() {
        if(!_uniqueName) {
            _uniqueName = mangle(this);
        }
        return _uniqueName;
    }

    //bool hasDefaultConstructor() {
    //    assert(type.isKnown);
    //    return getDefaultConstructor() !is null;
    //}
    //Function getDefaultConstructor() {
    //    assert(type.isKnown);
    //    foreach(f; getConstructors()) {
    //        if(f.isDefaultConstructor) return f;
    //    }
    //    return null;
    //}
    //Function[] getConstructors() {
    //    assert(type.isKnown);
    //    return type.getMemberFunctions("new");
    //}
    //========================================================================================
    override string description() {
        return "NamedStruct[refs=%s] %s".format(numRefs, toString());
    }
    override string toString() {
        string s;
        if(isTemplate()) {
            s ~= "<" ~ templateArgNames.join(",") ~ "> ";
        }
        return "%s%s%s".format(s, name, isKnown ? "":"?");
    }
}