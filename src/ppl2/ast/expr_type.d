module ppl2.ast.expr_type;

import ppl2.internal;

final class TypeExpr : Expression {
    Type type;

    static TypeExpr make(Type t) {
        auto e = makeNode!TypeExpr;
        e.type = t;
        return e;
    }

    override bool isResolved() { return type && type.isKnown; }
    override NodeID id() const { return NodeID.TYPE_EXPR; }
    override bool isConst() { return true; }
    override int priority() const { return 15; }
    override Type getType() { return type; }

    override string toString() {
        return "Type:%s".format(type);
    }
}