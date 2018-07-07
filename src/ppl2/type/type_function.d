module ppl2.type.type_function;

import ppl2.internal;

final class FunctionType : ASTNode, Type {
private:
    LLVMTypeRef _llvmType;
public:
    Type _returnType;       /// This gets calculated later by the FunctionLiteral if there is one
    Parameters params;      /// Point to Parameters of FunctionLiteral

    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.FUNC_TYPE; }
    override Type getType() { return this; }

    void returnType(Type t) {
        _returnType = t;
    }
    Type returnType() {
        if(params) return firstNotNull(_returnType, TYPE_UNKNOWN);
        return children[$-1].as!Variable.type;
    }

    Type[] paramTypes() {
        /// If there is a FunctionLiteral
        if(params) return params.paramTypes();
        /// Variable or extern function
        if(hasChildren) {
            return children[0..$-1].map!(it=>it.getType).array;
        }
        assert(false, "FunctionType has no children");
    }
    string[] paramNames() {
        /// If there is a FunctionLiteral
        if(params) return params.paramNames();
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
        return returnType().isKnown && paramTypes.areKnown();
    }
    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type

        if(!other.isFunction) return false;

        auto right = other.getFunctionType;

        if(!returnType.exactlyMatches(right.returnType())) return false;

        return .exactlyMatch(paramTypes(), right.paramTypes());
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isFunction) return false;

        auto right = other.getFunctionType;

        /// check returnType?

        return .exactlyMatch(paramTypes(), right.paramTypes());
    }
    LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = function_(returnType.getLLVMType(),
                                  paramTypes().map!(it=>it.getLLVMType()).array);
        }
        return _llvmType;
    }
    //============================================================
    override string description() {
        return "FunctionType:%s".format(toString());
    }
    override string toString() {
        string a;
        if(paramTypes().length == 0) {
            a = "void";
        } else {
            foreach (i, t; paramTypes()) {
                if (i>0) a ~= ",";
                a ~= "%s".format(t);
                //if (paramNames[i] !is null) a ~= " " ~ paramNames[i];
            }
        }
        return "{%s->%s}".format(a, returnType);
    }
}