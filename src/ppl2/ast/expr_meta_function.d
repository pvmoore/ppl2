module ppl2.ast.expr_meta_function;

import ppl2.internal;
///
/// Represents a compile-time function that needs to be folded into another Expression.
///
/// #size (in bytes)
/// #isptr
/// #init
///
/// Array properties:
///     #length
///
/// Struct properties:
///
///
/// Function properties:
///     #args   // returns array of Arg [#type] etc... todo
///         .length
///
///
final class MetaFunction : Expression {
    string name;

    override bool isResolved() { return false; }
    override bool isConst() { return true; }
    override NodeID id() const { return NodeID.META_FUNCTION; }
    override int priority() const { return 1; }
    override Type getType() { return TYPE_UNKNOWN; }

    /// Rewrite this as a literal
    void rewrite() {
        Expression expr = children[0].as!Expression;
        assert(expr);

        Expression replacement = expr;

        switch(name) {
            case "length":
                break;
            default:
                assert(false, "MetaProperty %s".format(name));
        }

        parent.replaceChild(this, replacement);
    }

    override string toString() {
        return "Meta (%s)".format(getType());
    }
}