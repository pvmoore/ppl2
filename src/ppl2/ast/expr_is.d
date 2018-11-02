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

        if(!left().isTypeExpr && !right().isTypeExpr) {
            /// Identifier is Identifier

            /// Both sides must be resolved
            if(leftType.isUnknown || rightType.isUnknown) return;

            if(leftType.isValue && rightType.isValue) {
                /// value is value

                /// Do a memory comparison regardless of the
                /// type as long as they are the same size

                if(leftType.size != rightType.size) {
                    getModule.addError(this,
                        "Both sides of value 'is' value expression should be the same size "~
                        "(%s -> %s)".format(leftType.size, rightType.size));
                    return;
                }

                /// Structs need to use memcmp
                if(leftType.isStruct && rightType.isStruct) {
                    rewriteToMemcmp();
                    return;
                }
                if(leftType.isArray && rightType.isArray) {
                    rewriteToMemcmp();
                    return;
                }

            } else if(!leftType.isPtr || !rightType.isPtr) {
                getModule.addError(this,
                    "Both sides if 'is' expression should be pointer types");
                return;
            }
        } else {
            /// Type is Type
            /// Type is Expression
            /// Expression is Type


            /// Special case - array subtype check.
            /// eg. expr is [:int]
            ///     [:bool] is expr
            ///
            //ArrayStruct leftArray  = leftType.getArrayStruct;
            //ArrayStruct rightArray = rightType.getArrayStruct;
            //if(leftArray && rightArray) {
            //    bool r  = (left.isTypeExpr && leftArray.subtype.isKnown && !leftArray.hasCountExpr);
            //         r |= (right.isTypeExpr && rightArray.subtype.isKnown && !rightArray.hasCountExpr);
            //
            //    if(r) {
            //        /// Do array subtype check only
            //        bool result = (leftType.getPtrDepth==rightType.getPtrDepth) &&
            //                      leftArray.subtype.exactlyMatches(rightArray.subtype);
            //        rewriteToConstBool(result);
            //        return;
            //    }
            //}

            /// Both sides must be resolved
            if(leftType.isUnknown || rightType.isUnknown) return;

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