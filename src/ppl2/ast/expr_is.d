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
    override NodeID id() const { return NodeID.IS; }
    override int priority() const { return 7; }
    override Type getType() { return TYPE_BOOL; }

    Expression left()  { return children[0].as!Expression; }
    Expression right() { return children[1].as!Expression; }

    Type leftType() { return left().getType; }
    Type rightType() { return right().getType; }

    Type oppositeSideType(Expression node) {
        if(left().nid==node.nid) {
            return rightType();
        } else if(right().nid==node.nid) {
            return leftType();
        }
        assert(false);
    }

    void resolve() {
        if(resolved) return;

        auto leftType  = leftType();
        auto rightType = rightType();

        /// Both sides must be resolved
        if(leftType.isUnknown || rightType.isUnknown) return;

        if(!left().isTypeExpr && !right().isTypeExpr) {
            /// Identifier is Identifier

            if(leftType.isValue && rightType.isValue) {
                /// value is value

                /// If the sizes are different then the result must be false
                if(leftType.size != rightType.size) {
                    rewriteToConstBool(false);
                    return;
                }

                /// If one side is a named struct then the other must be too
                if(leftType.isNamedStruct != rightType.isNamedStruct) {
                    rewriteToConstBool(false);
                    return;
                }

                /// If one side is an anon struct then the other side musy be too
                if(leftType.isAnonStruct != rightType.isAnonStruct) {
                    rewriteToConstBool(false);
                    return;
                }

                /// Two named structs
                if(leftType.isNamedStruct && rightType.isNamedStruct) {

                    /// Must be the same type
                    if(leftType.getNamedStruct != rightType.getNamedStruct) {
                        rewriteToConstBool(false);
                        return;
                    }

                    rewriteToMemcmp();
                    return;
                }

                /// Two anon structs
                if(leftType.isAnonStruct && rightType.isAnonStruct) {
                    rewriteToMemcmp();
                    return;
                }

                /// Two arrays
                if(leftType.isArray && rightType.isArray) {

                    /// Must be the same subtype
                    if(!leftType.getArrayType.subtype.exactlyMatches(rightType.getArrayType.subtype)) {
                        rewriteToConstBool(false);
                        return;
                    }

                    rewriteToMemcmp();
                    return;
                }

            } else if(!leftType.isPtr || !rightType.isPtr) {
                getModule.addError(this,
                    "Both sides if 'is' expression should be pointer types", true);
                return;
            }
        } else {
            /// Type is Type
            /// Type is Expression
            /// Expression is Type

            rewriteToConstBool(leftType.exactlyMatches(rightType));
        }
        resolved = true;
    }

    override string toString() {
        string neg = negate ? " not" : "";
        return "Is%s (%s)".format(neg, getType());
    }
private:
    void rewriteToConstBool(bool result) {
        result ^= negate;
        parent.replaceChild(this, LiteralNumber.makeConst(result ? TRUE : FALSE, TYPE_BOOL));
    }
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
        call.add(b.addressOf(left()));
        call.add(b.addressOf(right()));
        call.add(LiteralNumber.makeConst(leftType.size, TYPE_INT));

        auto op = negate ? Operator.COMPARE : Operator.BOOL_EQ;
        auto ne = b.binary(op, call, LiteralNumber.makeConst(0, TYPE_INT));

        parent.replaceChild(this, ne);
    }
}