module ppl2.ast.stmt_assert;

import ppl2.internal;

final class Assert : Statement {
    Target target;

    override bool isResolved() { return target && target.isResolved; }
    override NodeID id() const { return NodeID.ASSERT; }
    override Type getType() { return expr().getType; }

    Expression expr() { return first().as!Expression; }

    override string toString() {
        return "Assert";
    }
}