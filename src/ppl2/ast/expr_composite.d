module ppl2.ast.expr_composite;

import ppl2.internal;

///
/// Wrap one or more nodes to appear as one single node.
///
final class Composite : Expression {
    bool required;  /// Set to true to ensure this node cannot be removed even if it is empty

    static Composite make(TokenNavigator t, bool required = false) {
        auto c = makeNode!Composite(t);
        c.required = required;
        return c;
    }

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