module ppl2.ast.expr_call;

import ppl2.internal;

final class Call : Expression {
    string name;
    Target target;
    string[] paramNames;        /// optional. eg. name=value

/// Template stuff
    Type[] templateTypes;       /// optional. eg. func<int,bool>
/// end of template stuff

    bool implicitThisArgAdded;  /// true if 1st arg thisptr has been added

    int numArgs() {
        return numChildren();
    }
    Expression arg(int index) {
        assert(index<numChildren);
        return args()[index];
    }
    Expression[] args() {
        return children[].as!(Expression[]);
    }
    Type[] argTypes() {
        return types(args());
    }
    bool isTemplated() { return templateTypes.length>0 ;}

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