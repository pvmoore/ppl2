module ppl2.ast.expr_parenthesis;

import ppl2.internal;

final class Parenthesis : Expression  {

    override bool isResolved() { return expr.isResolved; }
    override bool isConst() { return expr().isConst; }
    override NodeID id() const { return NodeID.PARENTHESIS; }
    override int priority() const { return 15; }
    override Type getType() { return expr().getType(); }

    Expression expr() {
        return cast(Expression)first();
    }
    Type exprType() {
        return expr().getType;
    }

    override string toString() {
        return "() %s".format(getType());
    }
}