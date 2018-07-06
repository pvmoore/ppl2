module ppl2.ast.expr_is;

import ppl2.internal;
///
/// TypeExpr   is TypeExpr
/// Identifier is TypeExpr
/// Identifier is Identifier
///
/// Is
///     left
///     right
///
final class Is : Expression {
    bool negate;

    override bool isResolved() { return true; }
    override bool isConst() { return left().isConst && right().isConst; }
    override NodeID id() const { return NodeID.AS; }
    override int priority() const { return 7; }
    override Type getType() { return TYPE_BOOL; }

    Expression left()  { return children[0].as!Expression; }
    Expression right() { return children[1].as!Expression; }

    Type leftType() { return left().getType; }
    Type rightType() { return right().getType; }

    override string toString() {
        return "Is (%s)".format(getType());
    }
}