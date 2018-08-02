module ppl2.ast.expr_identifier;

import ppl2.internal;

final class Identifier : Expression {
    string name;
    Target target;

    override bool isResolved() { return target.isResolved; }
    override bool isConst() { return target.isResolved && target.isVariable && target.getVariable.isConst; }
    override NodeID id() const { return NodeID.IDENTIFIER; }
    override int priority() const { return 15; }
    override Type getType() { return target.getType(); }

    override string toString(){
        string c = isConst ? "const ":"";
        return "ID:%s (type=%s%s)".format(name, c, getType().prettyString);
    }
}