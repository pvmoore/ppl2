module ppl2.ast.expr_literal_null;

import ppl2.internal;

final class LiteralNull : Expression {
    Type type;

    this() {
        type = TYPE_UNKNOWN;
    }

    static LiteralNull makeConst(Type t=TYPE_UNKNOWN) {
        auto lit = makeNode!LiteralNull;
        lit.type = t;
        return lit;
    }

    override bool isResolved() { return type.isKnown; }
    override bool isConst() { return true; }
    override int priority() const { return 15; }
    override Type getType() { return type; }
    override NodeID id() const { return NodeID.LITERAL_NULL; }

    override string toString() {
        return "null (type=const %s)".format(type.prettyString);
    }
}