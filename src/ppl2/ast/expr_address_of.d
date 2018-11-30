module ppl2.ast.expr_address_of;

import ppl2.internal;

///
/// addressof ::= "#ptr(" expression ")"
///
final class AddressOf : Expression {
private:
    Type type;
public:
    override bool isResolved() { return expr.isResolved; }
    override bool isConst() { return expr().isConst; }
    override NodeID id() const { return NodeID.ADDRESS_OF; }
    override int priority() const { return 3; }

    override Type getType() {
        if(!expr().isResolved) return TYPE_UNKNOWN;

        if(type) {
            assert(type.getPtrDepth==expr().getType.getPtrDepth+1);
            return type;
        }

        auto t = expr().getType();
        type = Pointer.of(t, 1);
        return type;
    }

    Expression expr() { return children[0].as!Expression; }

    override string toString() {
        return "AddressOf (%s)".format(getType());
    }
}