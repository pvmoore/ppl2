module ppl2.ast.ExpressionRef;

import ppl2.internal;
///
/// Points to another Expression node so that we don't have to clone expression nodes.
///
final class ExpressionRef : Expression {
    Expression reference;

    static Expression make(Expression r) {
        auto ref_ = makeNode!ExpressionRef(r);
        ref_.reference = r;
        return ref_;
    }

    override bool isResolved()    { return reference.isResolved(); }
    override bool isConst()       { return reference.isConst(); }
    override NodeID id() const    { return reference.id(); }
    override int priority() const { return reference.priority(); }
    override Type getType()       { return reference.getType; }

    Expression expr() { return reference; }

    override string toString() {
        return "ref to %s".format(reference);
    }
}