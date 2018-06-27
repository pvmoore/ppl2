module ppl2.ast.expr_as;

import ppl2.internal;

final class As : Expression {

    override bool isResolved() { return getType.isKnown; }
    override bool isConst() { return left().isConst; }
    override NodeID id() const { return NodeID.AS; }
    override int priority() const { return 1; }
    override Type getType() { return rightType(); }

    Expression left() { return children[0].as!Expression; }
    Expression right() { return children[1].as!Expression; }

    Type leftType() { return left().getType; }
    Type rightType() { return right().getType; }

    override string toString() {
        return "As (%s)".format(getType());
    }
}