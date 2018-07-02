module ppl2.ast.stmt_assert;

import ppl2.internal;

final class Assert : Statement {

    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.ASSERT; }
    override Type getType() { return expr().getType; }

    Expression expr() { return first().as!Expression; }

    override string toString() {
        return "Assert";
    }
}