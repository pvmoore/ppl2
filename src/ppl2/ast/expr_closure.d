module ppl2.ast.expr_closure;

import ppl2.internal;
///
/// Closure
///     LiteralFunction
///
final class Closure : Expression {
    string name;

    LLVMValueRef llvmValue;

    override bool isResolved() { return true; }
    override bool isConst() { return false; }
    override NodeID id() const { return NodeID.CLOSURE; }
    override int priority() const { return 15; }
    override Type getType() { return getBody().getType(); }

    LiteralFunction getBody() {
        return first().as!LiteralFunction;
    }

    override string toString() {
        return "Closure %s".format(nid);
    }
}