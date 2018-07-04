module ppl2.ast.expr_value_of;

import ppl2.internal;

final class ValueOf : Expression {
    private Type type;

    override bool isResolved() { return expr.isResolved; }
    override bool isConst() { return expr().isConst; }
    override NodeID id() const { return NodeID.VALUE_OF; }
    override int priority() const { return 1; }

    override Type getType() {
        if(!expr().isResolved) return TYPE_UNKNOWN;

        if(type) {
            assert(type.getPtrDepth==expr().getType.getPtrDepth-1,
                "ptrdepth=%s %s".format(type.getPtrDepth, expr()));
            return type;
        }

        auto t = expr().getType();
        type = PtrType.of(t, -1);
        return type;
    }

    Expression expr() { return children[0].as!Expression; }

    override string toString() {
        return "ValueOf (%s)".format(getType);
    }
}