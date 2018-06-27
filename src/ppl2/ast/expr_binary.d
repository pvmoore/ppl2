module ppl2.ast.expr_binary;

import ppl2.internal;
/**
 *  binary_expression ::= expression op expression
 */
public class Binary : Expression {
    Type type;
    Operator op;

    this() {
        type = TYPE_UNKNOWN;
    }

    override bool isResolved() { return type.isKnown; }
    override bool isConst() { return left().isConst && right().isConst; }
    override NodeID id() const { return NodeID.BINARY; }
    override int priority() const { return op.priority; }
    override Type getType() { return type; }

    Expression left() {
        return cast(Expression)children[0];
    }
    Expression right() {
        return cast(Expression)children[1];
    }
    Type leftType() { assert(left()); return left().getType; }
    Type rightType() { assert(right()); return right().getType; }

    Expression otherSide(Expression e) {
        if(left().nid==e.nid) return right();
        if(right().nid==e.nid) return left();
        return null;
    }

    override string toString() {
        return "%s (type=%s)".format(op, getType());
    }
}
