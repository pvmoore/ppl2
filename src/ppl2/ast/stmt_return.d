module ppl2.ast.stmt_return;

import ppl2.internal;

final class Return : Statement {

    override bool isResolved() { return getType.isKnown; }
    override NodeID id() const { return NodeID.RETURN; }
    override Type getType() { return hasExpr ? expr().getType : TYPE_VOID; }

    bool hasExpr() {
        return numChildren > 0;
    }
    Expression expr() {
        return cast(Expression)first();
    }
    Type getReturnType() {
        auto func = getContaining!Function;
        assert(func);
        auto type = func.getType.getFunctionType;
        assert(type);
        return type.returnType;
    }

    override string toString() {
        return "return";
    }
}