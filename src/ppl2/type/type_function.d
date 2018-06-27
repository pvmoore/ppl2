module ppl2.type.type_function;

import ppl2.internal;

final class FunctionType : ASTNode, Type {
    Type _returnType;       /// This gets calculated later by the FunctionLiteral if there is one
    Arguments args;         /// Point to Arguments of FunctionLiteral

    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.FUNC_TYPE; }
    override Type getType() { return this; }

    void returnType(Type t) {
        _returnType = t;
    }
    Type returnType() {
        if(args) return firstNotNull(_returnType, TYPE_UNKNOWN);
        return children[$-1].as!Variable.type;
    }

    Type[] argTypes() {
        /// If there is a FunctionLiteral
        if(args) return args.argTypes();
        /// Variable or extern function
        if(hasChildren) {
            return children[0..$-1].map!(it=>it.getType).array;
        }
        assert(false, "FunctionType has no children");
    }
    string[] argNames() {
        /// If there is a FunctionLiteral
        if(args) return args.argNames();
        /// Variable or extern function
        if(hasChildren) {
            return children[0..$-1].map!(it=>it.as!Variable.name).array;
        }
        assert(false, "FunctionType has no children");
    }

/// Type interface
    int getEnum() const {
        return Type.FUNCTION;
    }
    bool isKnown() {
        return returnType().isKnown && argTypes.areKnown();
    }
    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type

        if(!other.isFunction) return false;

        auto right = other.getFunctionType;

        /// check returnType?

        return .exactlyMatch(argTypes, right.argTypes);
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isFunction) return false;

        auto right = other.getFunctionType;

        /// check returnType?

        return .exactlyMatch(argTypes, right.argTypes);
    }
    Expression defaultInitialiser() {
        assert(isKnown);
        /// Assume this is always a ptr
        return LiteralNull.makeConst(this);
    }
    //============================================================
    override string description() {
        return "FunctionType:%s".format(toString());
    }
    override string toString() {
        string a;
        if(argTypes.length == 0) {
            a = "void";
        } else {
            foreach (i, t; argTypes) {
                if (i>0) a ~= ",";
                a ~= "%s".format(t);
                if (argNames[i] !is null) a ~= " " ~ argNames[i];
            }
        }
        return "{%s->%s}".format(a, returnType);
    }
}