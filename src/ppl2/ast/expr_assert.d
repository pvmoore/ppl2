module ppl2.ast.expr_assert;

import ppl2.internal;

final class Assert : Expression {

    override bool isResolved() { return true; }
    override bool isConst() { return expr().isConst; }
    override NodeID id() const { return NodeID.ASSERT; }
    override int priority() const { return 15; }
    override Type getType() { return expr().getType; }

    Expression expr() { return first().as!Expression; }

    override string toString() {
        return "Assert";
    }
}