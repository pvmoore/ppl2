module ppl2.ast.expr_builtin_func;

import ppl2.internal;
///
/// #sizeof     (expr)
/// #typeof     (expr)
/// #initof     (expr)
/// #isptr      (expr)
/// #isvalue    (expr)
///
final class BuiltinFunc : Expression {
    string name;

    override bool isResolved()    { return false; }
    override bool isConst()       { return true; }
    override NodeID id() const    { return NodeID.BUILTIN_FUNC; }
    override int priority() const { return 2; }
    override Type getType()       { return TYPE_UNKNOWN; }

    int numExprs()       { return numChildren; }
    Expression[] exprs() { return children[].as!(Expression[]); }
    Type[] exprTypes()   { return exprs().types(); }

    override string toString() {
        return "%s".format(name);
    }
}