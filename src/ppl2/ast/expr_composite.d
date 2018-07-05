module ppl2.ast.expr_composite;

import ppl2.internal;

///
/// Wrap one or more nodes to appear as one single node.
///
final class Composite : Expression {

    override bool isResolved() { return areResolved(children[]); }
    override NodeID id() const { return NodeID.COMPOSITE; }
    override int priority() const { return 15; }

    /// The type is the type of the last element
    override Type getType() {
        if(hasChildren) return last().getType();
        return TYPE_VOID;
    }

    override string toString() {
        return "Composite (type=%s)".format(getType);
    }
}