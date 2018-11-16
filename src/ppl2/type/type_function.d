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

    int numParams() {
        if(params) return params.numParams;
        return numChildren-1;
    }
    Type[] paramTypes() {
        /// If there is a FunctionLiteral
        if(params) return params.paramTypes();

        /// Variable or extern function
        assert(children[].all!(it=>it.isVariable));
        assert(numChildren > 0, "FunctionType has no children");

        /// Last child will be the return type
        return children[0..$-1].map!(it=>it.getType).array;
    }
    string[] paramNames() {
        /// If there is a FunctionLiteral
        if(params) return params.paramNames();

        /// Variable or extern function
        assert(children[].all!(it=>it.isVariable));
        assert(numChildren > 0, "FunctionType has no children");

        /// Last child will be the return type
        return children[0..$-1].map!(it=>it.as!Variable.name).array;
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

        /// check returnType
        if(!returnType.exactlyMatches(right.returnType())) return false;

        /// Turn {->?} into {void->?}
        auto pt  = paramTypes();
        auto pt2 = right.paramTypes();
        //if(pt.length==0) {
        //    pt = [TYPE_VOID];
        //}
        //if(pt2.length==0) {
        //    pt2 = [TYPE_VOID];
        //}

        return .exactlyMatch(pt, pt2);
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isFunction) return false;
        auto right = other.getFunctionType;

        /// check returnType
        if(!returnType.exactlyMatches(right.returnType)) return false;

        /// Turn {->?} into {void->?}
        auto pt  = paramTypes();
        auto pt2 = right.paramTypes();
        //if(pt.length==0) {
        //    pt = [TYPE_VOID];
        //}
        //if(pt2.length==0) {
        //    pt2 = [TYPE_VOID];
        //}

        return .exactlyMatch(pt, pt2);
    }
    LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = function_(returnType.getLLVMType(),
                                  paramTypes().map!(it=>it.getLLVMType()).array);
        }
        return _llvmType;
    }
    //string prettyString() {
    //    auto buf = new StringBuffer;
    //    buf.add("{");
    //    foreach(i, t; paramTypes()) {
    //        if(i>0) buf.add(", ");
    //        buf.add(t.prettyString());
    //    }
    //    buf.add("->");
    //    buf.add(returnType.prettyString());
    //    buf.add("}");
    //    return buf.toString;
    //}
    //override string toString() {
    //    string a;
    //    if(paramTypes().length == 0) {
    //        a = "void";
    //    } else {
    //        foreach (i, t; paramTypes()) {
    //            if (i>0) a ~= ",";
    //            a ~= "%s".format(t.prettyString);
    //            //if (paramNames[i] !is null) a ~= " " ~ paramNames[i];
    //        }
    //    }
    //    return "{%s->%s}".format(a, returnType);
    //}
    //============================================================
    override string toString() {
        if(!isKnown) return "{?->?}";
        string params = "%s".format(paramTypes().length == 0 ? "void" : paramTypes().toString());
        return "{%s->%s}".format(params, returnType());
    }
}