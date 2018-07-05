module ppl2.ast.expr_call;

import ppl2.internal;

final class Call : Expression {
    string name;
    Target target;

    int numArgs() {
        return numChildren();
    }
    Expression arg(int index) {
        assert(index<numChildren);
        return children[index].to!Expression;
    }

    override bool isResolved() { return target.isResolved; }
    override NodeID id() const { return NodeID.CALL; }
    override int priority() const { return 1; }
    override Type getType() {
        if(!target.isResolved) return TYPE_UNKNOWN;
        return target.getType().getFunctionType.returnType;
    }

    override string toString() {
        if(target.isResolved){
            return "Call %s".format(target);
        }
        return "Call %s".format(name);
    }
}