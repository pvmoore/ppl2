module ppl2.ast.expr_composite;

import ppl2.internal;

///
/// Wrap one or more nodes to appear as one single node.
///
final class Composite : Expression {
    enum Usage {
        STANDARD,      /// Can be removed. Can be replaced if contains single child
        PERMANENT,     /// Never remove or replace even if empty
        PLACEHOLDER    /// Never remove. Can be replaced if contains single child
    }

    Usage usage = Usage.STANDARD;

    static Composite make(Tokens t, Usage usage) {
        auto c  = makeNode!Composite(t);
        c.usage = usage;
        return c;
    }
    static Composite make(ASTNode node, Usage usage) {
        auto c  = makeNode!Composite(node);
        c.usage = usage;
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
    bool endsWithReturn() {
        return numChildren > 0 && last().isReturn;
    }

    bool isPlaceholder() { return usage==Usage.PLACEHOLDER; }

    override string toString() {
        return "Composite %s %s(type=%s)".format(usage, nid, getType);
    }
}