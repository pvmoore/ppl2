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

    override bool isResolved() { return type.isKnown && left().isResolved && right.isResolved; }
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

    void rewriteToOperatorOverloadCall() {
        auto struct_ = leftType.getAnonStruct;
        assert(struct_);

        auto b = getModule.builder(this);

        switch(op.id) with(Operator) {
            case LT.id:
            case LTE.id:
            case GT.id:
            case GTE.id:
            case BOOL_EQ.id:
            case COMPARE.id:
                /// Binary
                ///     left struct
                ///     right
                /// .....................
                /// Binary [< | <= | > | >= | == | <>]
                ///     Dot
                ///         [AddressOf] left struct
                ///         Call operator<>
                ///             right
                ///     0
                auto left = leftType.isValue ? b.addressOf(this.left) : this.left;
                auto call = b.call("operator<>", null)
                             .add(this.right);

                auto dot = b.dot(left, call.as!Expression);

                add(dot);
                add(LiteralNumber.makeConst(0, TYPE_INT));
                break;
            default:
                /// Binary
                ///     left struct
                ///     right
                /// .....................
                /// Dot
                ///     [AddressOf] left struct
                ///     Call
                ///         right
                auto left  = leftType.isValue ? b.addressOf(this.left) : this.left;
                auto right = b.call("operator" ~ op.value, null)
                              .add(this.right);

                auto dot = b.dot(left, right.as!Expression);

                parent.replaceChild(this, dot);
                break;
        }
    }

    override string toString() {
        return "%s (type=%s)".format(op, getType());
    }
}
