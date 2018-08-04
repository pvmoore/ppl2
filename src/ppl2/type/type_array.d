module ppl2.type.type_array;

import ppl2.internal;
///
/// array_type::= "[" type ":" count_expr "]"
///
/// array_type
///     count_expr
///
final class ArrayType : ASTNode, Type {
private:
    LLVMTypeRef _llvmType;
public:
    Type subtype;

    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.ARRAY; }
    override Type getType() { return this; }

/// Type
    int getEnum() const { return Type.ARRAY; }

    bool isKnown() {
        return subtype.isKnown() && countExpr().isResolved && countExpr().isA!LiteralNumber;
    }
    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type
        if(!other.isArray) return false;

        auto rightArray = other.getArrayType;

        if(!rightArray.subtype.exactlyMatches(subtype)) return false;

        return countAsInt() == rightArray.countAsInt();
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isArray) return false;

        auto rightArray = other.getArrayType;

        if(!rightArray.subtype.exactlyMatches(subtype)) return false;

        return countAsInt() == rightArray.countAsInt();
    }
    LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = arrayType(subtype.getLLVMType(), countAsInt());
        }
        return _llvmType;
    }
    string prettyString() {
        string c;
        if(isResolved) {
            c = countAsInt().to!string;
        } else {
            c = "?";
        }
        return "[:%s %s]".format(subtype.prettyString(), c);
    }
    //============================================================
    void setCount(LiteralNumber lit) {
        assert(numChildren==1);

        last().detach();
        add(lit);
    }
    Expression countExpr() {
        assert(numChildren>0, "Expecting a countExpr");
        assert(last().isExpression);
        assert(subtype !is this);

        return last().as!Expression;
    }
    int countAsInt() {
        if(!isResolved) return -1;
        assert(countExpr().isA!LiteralNumber,
            "Expecting count to be a literal number (it is a %s)".format(typeid(countExpr())));
        return countExpr().as!LiteralNumber.value.getInt();
    }
    override string toString() {
        string c;
        if(isResolved) {
            c = countAsInt().to!string;
        } else {
            c = "%s".format(countExpr());
        }
        return "ArrayType [%s:%s] (nid=%s)".format(subtype.prettyString, c, nid);
    }
}