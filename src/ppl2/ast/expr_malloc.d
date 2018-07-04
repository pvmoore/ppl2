module ppl2.ast.expr_malloc;

import ppl2.internal;
///
/// Allocate a type on the heap
///
final class Malloc : Expression {
private:
    Type ptrType;
public:
    Type valueType;

    override bool isResolved() { return valueType.isKnown; }
    override bool isConst() { return false; }
    override NodeID id() const { return NodeID.MALLOC; }
    override int priority() const { return 15; }
    override Type getType() {
        if(!ptrType) {
            ptrType = PtrType.of(valueType, 1);
        }
        return ptrType;
    }

    override string toString() {
        return "Malloc (%s)".format(getType());
    }
}