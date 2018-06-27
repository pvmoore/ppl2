module ppl2.ast.expr_dot;

import ppl2.internal;
/**
 *  dot_expr::= expression "." expression
 */
final class Dot : Expression {

    override bool isResolved() { return getType.isKnown; }
    override NodeID id() const { return NodeID.DOT; }
    override int priority() const { return 1; }
    override Type getType() {
        if(right() is null) return TYPE_UNKNOWN;
        return right().getType;
    }

    Expression left() { return cast(Expression)first(); }
    Expression right() { return cast(Expression)last(); }

    override string toString() {
        return "Dot (type=%s)".format(getType);
    }
}