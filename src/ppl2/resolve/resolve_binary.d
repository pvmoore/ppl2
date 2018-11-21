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

        if(lt.isNamedStruct) {
            if(n.op.isOverloadable || n.op.isComparison) {
                n.rewriteToOperatorOverloadCall();
                resolver.setModified();
                return;
            }
        }

        /// ==
        if(n.op==Operator.BOOL_EQ) {
            bool bothValues = lt.isValue && rt.isValue;
            bool bothTuples = lt.isAnonStruct && rt.isAnonStruct;

            /// Rewrite anonstruct == anonstruct --> is_expr
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

            //if(lt.isKnown && rt.isKnown) {
            /// If we are assigning then take the type of the lhs expression
            if(n.op.isAssign) {
                n.type = lt;
            } else if(n.op.isBool) {
                n.type = TYPE_BOOL;
            } else {
                /// Set to largest of left or right type

                auto t = getBestFit(lt, rt);
                /// Promote byte, short to int
                if(t.isValue && t.isInteger && t.category < TYPE_INT.category) {
                    n.type = TYPE_INT;
                } else {
                    n.type = t;
                }
            }
            //}
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
}