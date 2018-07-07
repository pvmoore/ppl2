module ppl2.ast.expr_is;

import ppl2.internal;
///
/// TypeExpr   is TypeExpr
/// Identifier is TypeExpr
/// Identifier is Identifier
///
/// Is
///     left
///     right
///
final class Is : Expression {
private:
    bool resolved;
public:
    bool negate;

    override bool isResolved() { return resolved; }
    override bool isConst() { return left().isConst && right().isConst; }
    override NodeID id() const { return NodeID.AS; }
    override int priority() const { return 7; }
    override Type getType() { return TYPE_BOOL; }

    Expression left()  { return children[0].as!Expression; }
    Expression right() { return children[1].as!Expression; }

    Type leftType() { return left().getType; }
    Type rightType() { return right().getType; }

    void resolve() {
        if(resolved) return;

        auto leftType  = leftType();
        auto rightType = rightType();

        if(leftType.isUnknown || rightType.isUnknown) return;

        resolved = true;

        if(!left().isTypeExpr && !right().isTypeExpr) {
            /// Identifier is Identifier

            if(leftType.isValue && rightType.isValue) {
                /// value is value

                /// Do a memory comparison regardless of the
                /// type as long as they are the same size

                if(leftType.size != rightType.size) {
                    throw new CompilerError(Err.IS_BOTH_SIDES_MUST_BE_SAME_SIZE, this,
                    "Both sides of value 'is' value expression should be the same size");
                }

                /// Structs need to use memcmp
                if(leftType.isStruct && rightType.isStruct) {
                    rewriteToMemcmp();
                    return;
                }

            } else if(!leftType.isPtr || !rightType.isPtr) {
                throw new CompilerError(Err.IS_BOTH_SIDES_MUST_BE_POINTERS, this,
                    "Both sides if 'is' expression should be pointer types");
            }
        } else {
            /// Type is Type
            /// Type is Expression
            /// Expression is Type

            bool b= leftType.exactlyMatches(rightType);
            b ^= negate;
            parent.replaceChild(this, LiteralNumber.makeConst(b, TYPE_BOOL));
        }
    }

    override string toString() {
        string neg = negate ? " not" : "";
        return "Is%s (%s)".format(neg, getType());
    }
private:
    ///
    /// Binary (EQ)
    ///     call memcmp
    ///         Addressof
    ///             left
    ///         Addressof
    ///             right
    ///         long numBytes
    /// 0
    void rewriteToMemcmp() {
        assert(leftType.isValue);
        assert(rightType.isValue);

        auto b = getModule.builder(this);

        auto call = b.call("memcmp", null);
        call.addToEnd(b.addressOf(left()));
        call.addToEnd(b.addressOf(right()));
        call.addToEnd(LiteralNumber.makeConst(leftType.size, TYPE_INT));

        auto ne = b.binary(Operator.BOOL_EQ, call, LiteralNumber.makeConst(0, TYPE_INT));

        parent.replaceChild(this, ne);
    }
}