module ppl2.ast.expr_literal_expr_list;

import ppl2.internal;

///
/// "[" { expr { "," expr } } "]"
///
final class LiteralExpressionList : Expression {

    override bool isResolved() { return false; }
    override NodeID id() const { return NodeID.LITERAL_EXPR_LIST; }
    override int priority() const { return 15; }
    override Type getType() { return TYPE_UNKNOWN; }

    override string toString() {
        return "Literal array or struct";
    }
}