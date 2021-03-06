module ppl2.ast.expr_as;

import ppl2.internal;
///
/// As
///    expr
///    type
///
final class As : Expression {

    override bool isResolved() { return left().isResolved && getType.isKnown; }
    override bool isConst() { return true; }
    override NodeID id() const { return NodeID.AS; }
    override int priority() const { return 3; }
    override Type getType() { return rightType(); }

    Expression left()  { return children[0].as!Expression; }
    Expression right() { return children[1].as!Expression; }

    Type leftType()  { return left().getType; }
    Type rightType() { return right().getType; }

    override string toString() {
        return "As (%s)".format(getType());
    }
}