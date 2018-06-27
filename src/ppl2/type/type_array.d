module ppl2.type.type_array;

import ppl2.internal;
///
/// array_type::= "[" type ":" count_expr "]"
///
/// array_type
///     count_expr
///
final class ArrayType : ASTNode, Type {
    Type subtype;
    bool inferCount;

    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.ARRAY; }
    override Type getType() { return this; }

/// Type
    int getEnum() const { return Type.ARRAY; }

    bool isKnown() {
        return subtype.isKnown() && hasCountExpr() && countExpr().isResolved && countExpr().isA!LiteralNumber;
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
    Expression defaultInitialiser() {
        assert(isKnown);

        /// Create a literal array
        auto lit         = makeNode!LiteralArray(this);
        lit.type         = this;
        lit.isIndexBased = true;

        lit.addToEnd(LiteralNumber.makeConst(countAsInt() - 1, TYPE_INT));
        lit.addToEnd(subtype.defaultInitialiser());

        return lit;
    }
    //============================================================
    bool hasCountExpr() {
        return numChildren > 0;
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
        string c = inferCount ? "infer" : hasCountExpr() ? "%s".format(countExpr()) : "?";
        return "ArrayType:[nid=%s, subtype=%s, count=%s]".format(nid, subtype, c);
    }
}