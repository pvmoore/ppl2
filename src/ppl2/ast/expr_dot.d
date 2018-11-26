module ppl2.ast.expr_dot;

import ppl2.internal;
///
/// dot ::= expression "." expression
///
final class Dot : Expression {

    override bool isResolved()    { return getType.isKnown && left().isResolved && right().isResolved; }
    override NodeID id() const    { return NodeID.DOT; }
    override int priority() const { return 2; }
    override Type getType() {
        if(right() is null) return TYPE_UNKNOWN;
        return right().getType;
    }

    Expression left()  { return cast(Expression)first(); }
    Expression right() { return cast(Expression)last(); }

    Type leftType()  { return left().getType; }
    Type rightType() { return right().getType; }

    override string toString() {
        return ". (type=%s)".format(getType);
    }
}