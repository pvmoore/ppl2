module ppl2.ast.expr_composite;

import ppl2.internal;

final class CompositeExpression : Expression {

    override bool isResolved() { return areResolved(children[]); }
    override bool isConst() { return false; }
    override NodeID id() const { return NodeID.COMPOSITE; }
    override int priority() const { return 15; }

    /// The type is the type of the last element
    override Type getType() { return last().getType(); }

    override string toString() {
        return "Composite";
    }
}