module ppl2.resolve.resolve_binary;

import ppl2.internal;

final class BinaryResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Binary n) {
        auto lt      = n.leftType();
        auto rt      = n.rightType();
        auto builder = module_.builder(n);

        if(n.op==Operator.BOOL_AND) {
            auto p = n.parent.as!Binary;
            if(p && p.op==Operator.BOOL_OR) {
                module_.addError(n, "Parenthesis required to disambiguate these expressions", true);
            }
        }
        if(n.op==Operator.BOOL_OR) {
            auto p = n.parent.as!Binary;
            if(p && p.op==Operator.BOOL_AND) {
                module_.addError(n, "Parenthesis required to disambiguate these expressions", true);
            }
        }

        /// We need the types before we can continue
        if(lt.isUnknown || rt.isUnknown) {
            return;
        }

        /// Handle enums
        if(handleEnums(n, lt, rt)) return;

        if((lt.isStruct && lt.isValue) || (rt.isStruct && rt.isValue)) {
            if(n.op.isOverloadable || n.op.isComparison) {
                rewriteToOperatorOverloadCall(n);
                return;
            }
        }

        //if(lt.isStruct && lt.isPtr) {
        //    if(n.op.isComparison) {
        //        rewriteToOperatorOverloadCall(n);
        //        return;
        //    }
        //}

        /// ==
        if(n.op==Operator.BOOL_EQ) {
            bool bothValues = lt.isValue && rt.isValue;
            bool bothTuples = lt.isTuple && rt.isTuple;

            /// Rewrite tuple == tuple --> is_expr
            /// [int] a = [1]
            /// a == [1,2,3]
            if(bothValues && bothTuples) {
                auto isExpr = makeNode!Is(n);
                isExpr.add(n.left);
                isExpr.add(n.right);

                resolver.fold(n, isExpr);
                return;
            }
        }

        if(n.type.isUnknown) {

            /// If we are assigning then take the type of the lhs expression
            if(n.op.isAssign) {
                n.type = lt;

                if(n.op.isPtrArithmetic && lt.isPtr && rt.isInteger) {
                    n.isPtrArithmetic = true;
                }

            } else if(n.op.isBool) {
                n.type = TYPE_BOOL;
            } else {

                if(n.op.isPtrArithmetic && lt.isPtr && rt.isInteger) {
                    /// ptr +/- integer
                    n.type = lt;
                    n.isPtrArithmetic = true;
                } else if(n.op.isPtrArithmetic && lt.isInteger && rt.isPtr) {
                    /// integer +/- ptr
                    n.type = rt;
                    n.isPtrArithmetic = true;
                } else {
                    /// Set to largest of left or right type



                    auto t = getBestFit(lt, rt);

                    if(!t) {
                        module_.addError(n, "Types are incompatible %s and %s".format(lt, rt), true);
                        return;
                    }

                    /// Promote byte, short to int
                    if(t.isValue && t.isInteger && t.category < TYPE_INT.category) {
                        n.type = TYPE_INT;
                    } else {
                        n.type = t;
                    }
                }
            }
        }

        /// If left and right expressions are const numbers then evaluate them now
        /// and replace the Binary with the result
        if(n.isResolved && n.isConst) {

            // todo - make this work
            if(n.op.isAssign) return;

            auto leftLit  = n.left().as!LiteralNumber;
            auto rightLit = n.right().as!LiteralNumber;
            if(leftLit && rightLit) {

                auto lit = leftLit.copy();

                lit.value.applyBinary(n.type, n.op, rightLit.value);
                lit.str = lit.value.getString();

                resolver.fold(n, lit);
                return;
            }
        }
    }
private:
    /// Return true if we modified something
    bool handleEnums(Binary n, Type lt, Type rt) {
        if(!lt.isEnum && !rt.isEnum) return false;

        /// No special handling for =
        if(n.op==Operator.ASSIGN) return false;

        /// We have at least one side being an enum, maybe both

        auto builder = module_.builder(n);
        Enum enum_;

        /// += for example
        if(n.op.isAssign) {

            /// Rewrite:
            ///
            /// a += expr
            /// to:
            /// a = a + expr

            /// If left is not an identifier then bail out
            if(!n.left().isIdentifier) return false;

            auto id   = n.left().as!Identifier;
            auto id2  = builder.identifier(id.name);
            auto bin2 = builder.binary(n.op.removeAssign(), id2, n.right());
            n.add(bin2);

            n.op = Operator.ASSIGN;

            resolver.setModified();
            return true;

        } else {
            /// Rewrite these as .value

            if(lt.isEnum && lt.isValue) {
                auto value = builder.enumMemberValue(lt.getEnum, n.left());
                n.addToFront(value);
                enum_    = lt.getEnum;
                resolver.setModified();
            }
            if(rt.isEnum && rt.isValue) {
                auto value = builder.enumMemberValue(rt.getEnum, n.right());
                n.add(value);
                enum_    = rt.getEnum;
                resolver.setModified();
            }
            if(enum_) {
                if(!n.op.isBool) {
                    /// Rewrite to:
                    /// As enum
                    ///     Binary
                    auto as = makeNode!As(n);
                    resolver.fold(n, as);

                    as.add(n);
                    as.add(TypeExpr.make(enum_));
                }
                return true;
            }
        }
        //if(lt.isEnum) {
        //    if(n.op.isOverloadable || n.op.isComparison) {
        //        // todo - call enum operator overload ?
        //    }
        //}
        return false;
    }
    void rewriteToOperatorOverloadCall(Binary n) {
        Struct leftStruct = n.leftType.getStruct;
        Struct rightStruct = n.rightType.getStruct;

        assert(leftStruct || rightStruct);

        /// Swap left and right if the struct is on the rhs and op is commutative
        if(!leftStruct) {
            /// eg.
            /// 1 + struct
            /// 1 == struct

            if(n.op.isCommutative || n.op.isBool) {

                /// Reverse the operation
                auto op2 = n.op;
                if(!n.op.isCommutative) {
                    op2 = n.op.switchLeftRightBool();
                }

                if(rightStruct.hasOperatorOverload(op2)) {
                    /// Swap left and right
                    auto left = n.left();
                    left.detach();
                    n.add(left);

                    leftStruct  = rightStruct;
                    rightStruct = null;

                    n.op = op2;
                } else {
                    module_.addError(n, "Struct '%s' does not overload operator%s"
                        .format(rightStruct.name, op2.value), true);
                    return;
                }
            } else {
                module_.addError(n, "Invalid overload %s.operator%s(%s)"
                                    .format(n.leftType, n.op.value, n.rightType), true);
                return;
            }
        }

        auto b = module_.builder(n);

        Expression expr;

        /// Try to call the requested operator overload if it is defined.

        if(leftStruct.hasOperatorOverload(n.op)) {
            if(n.op.isAssign) {
                auto leftPtr = leftStruct.isValue ? b.addressOf(n.left) : n.left;
                expr = b.dot(leftPtr, b.call("operator"~n.op.value).add(n.right));
            } else {
                expr = b.dot(n.left, b.call("operator"~n.op.value).add(n.right));
            }
            resolver.fold(n, expr);
            return;
        }

        /// The specific operator overload is not defined.
        /// We can still continue if it is a bool operation
        /// and we can make it work using other defined operators

        /// Missing op | Rewrite to
        /// -----------------------------------------
        ///    ==      | not left.operator<>(right)
        ///    <>      | not left.operator==(right)
        ///     <      | not left.operator>=(right) ** right.operator>(left)  / not right.operator<=(left)
        ///     >      | not left.operator<=(right) ** right.operator<(left)  / not right.operator>=(left)
        ///    <=      | not left.operator>(right)  ** right.operator>=(left) / not right.operator<(left)
        ///    >=      | not left.operator<(right)  ** right.operator<=(left) / not right.operator>(left)

        /// ** Not implemented (Only works if right is a struct) Also there could be subtle issues

        switch(n.op.id) with(Operator) {
            case BOOL_EQ.id:
                if(leftStruct.hasOperatorOverload(BOOL_NE)) {
                    expr = b.dot(n.left, b.call("operator<>").add(n.right));
                    expr = b.not(expr);
                    resolver.fold(n, expr);
                    return;
                }
                break;
            case BOOL_NE.id:
                if(leftStruct.hasOperatorOverload(Operator.BOOL_EQ)) {
                    expr = b.dot(n.left, b.call("operator==").add(n.right));
                    expr = b.not(expr);
                    resolver.fold(n, expr);
                    return;
                }
                break;
            case LT.id:
                if(leftStruct.hasOperatorOverload(Operator.GTE)) {
                    expr = b.dot(n.left, b.call("operator>=").add(n.right));
                    expr = b.not(expr);
                    resolver.fold(n, expr);
                    return;
                }
                break;
            case GT.id:
                if(leftStruct.hasOperatorOverload(Operator.LTE)) {
                    expr = b.dot(n.left, b.call("operator<=").add(n.right));
                    expr = b.not(expr);
                    resolver.fold(n, expr);
                    return;
                }
                if(rightStruct) {

                }
                break;
            case LTE.id:
                if(leftStruct.hasOperatorOverload(Operator.GT)) {
                    expr = b.dot(n.left, b.call("operator>").add(n.right));
                    expr = b.not(expr);
                    resolver.fold(n, expr);
                    return;
                }
                if(rightStruct) {

                }
                break;
            case GTE.id:
                if(leftStruct.hasOperatorOverload(Operator.LT)) {
                    expr = b.dot(n.left, b.call("operator<").add(n.right));
                    expr = b.not(expr);
                    resolver.fold(n, expr);
                    return;
                }
                break;
            default:
                break;
        }

        module_.addError(n, "Struct %s does not overload operator%s"
                            .format(leftStruct.name, n.op.value), true);
    }
}