module ppl2.resolve.resolve_is;

import ppl2.internal;

final class IsResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Is n) {
        auto leftType  = n.leftType();
        auto rightType = n.rightType();

        /// Both sides must be resolved
        if(leftType.isUnknown || rightType.isUnknown) return;

        if(!n.left().isTypeExpr && !n.right().isTypeExpr) {
            /// Identifier IS Identifier

            if(leftType.isValue && rightType.isValue) {
                /// value IS value

                /// If the sizes are different then the result must be false
                if(leftType.size != rightType.size) {
                    rewriteToConstBool(n, false);
                    return;
                }

                /// If one side is a named struct then the other must be too
                if(leftType.isNamedStruct != rightType.isNamedStruct) {
                    rewriteToConstBool(n, false);
                    return;
                }
                /// If one side is an anon struct then the other side must be too
                if(leftType.isAnonStruct != rightType.isAnonStruct) {
                    rewriteToConstBool(n, false);
                    return;
                }
                /// If one side is an array then the other must be too
                if(leftType.isArray != rightType.isArray) {
                    rewriteToConstBool(n, false);
                    return;
                }
                /// If one side is a function then the other side must be too
                if(leftType.isFunction != rightType.isFunction) {
                    rewriteToConstBool(n, false);
                    return;
                }
                /// If one side is an enum then the other side must be too
                if(leftType.isEnum != rightType.isEnum) {
                    rewriteToConstBool(n, false);
                    return;
                }

                /// Two named structs
                if(leftType.isNamedStruct) {

                    /// Must be the same type
                    if(leftType.getNamedStruct != rightType.getNamedStruct) {
                        rewriteToConstBool(n, false);
                        return;
                    }

                    rewriteToMemcmp(n);
                    return;
                }

                /// Two anon structs
                if(leftType.isAnonStruct) {
                    rewriteToMemcmp(n);
                    return;
                }

                /// Two enums
                if(leftType.isEnum) {
                    auto leftEnum  = leftType.getEnum;
                    auto rightEnum = rightType.getEnum;

                    /// Must be the same enum type
                    if(!leftEnum.exactlyMatches(rightEnum)) {
                        rewriteToConstBool(n, false);
                        return;
                    }

                    rewriteToEnumMemberValues(n, leftEnum);
                    return;
                }

                /// Two arrays
                if(leftType.isArray) {

                    /// Must be the same subtype
                    if(!leftType.getArrayType.subtype.exactlyMatches(rightType.getArrayType.subtype)) {
                        rewriteToConstBool(n, false);
                        return;
                    }

                    rewriteToMemcmp(n);
                    return;
                }

                /// Two functions
                if(leftType.isFunction) {
                    assert(false, "implement me");
                }

                assert(leftType.isBasicType);
                assert(rightType.isBasicType);

                rewriteToBoolEquals(n);
                return;

            } else if(leftType.isPtr != rightType.isPtr) {
                module_.addError(n, "Both sides if 'is' expression should be pointer types", true);
                return;
            }

            /// ptr is ptr
            /// This is the only one that stays as an Is
            assert(leftType.isPtr && rightType.isPtr);

            return;

        } else {
            /// Type is Type
            /// Type is Expression
            /// Expression is Type

            rewriteToConstBool(n, leftType.exactlyMatches(rightType));
            return;
        }
    }
private:
    void rewriteToConstBool(Is n, bool result) {
        result ^= n.negate;

        auto lit = LiteralNumber.makeConst(result ? TRUE : FALSE, TYPE_BOOL);

        resolver.fold(n, lit);
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
    void rewriteToMemcmp(Is n) {
        assert(n.leftType.isValue);
        assert(n.rightType.isValue);

        auto builder = module_.builder(n);

        auto call = builder.call("memcmp", null);
        call.add(builder.addressOf(n.left()));
        call.add(builder.addressOf(n.right()));
        call.add(LiteralNumber.makeConst(n.leftType.size, TYPE_INT));

        auto op = n.negate ? Operator.COMPARE : Operator.BOOL_EQ;
        auto ne = builder.binary(op, call, LiteralNumber.makeConst(0, TYPE_INT));

        resolver.fold(n, ne);
    }
    void rewriteToBoolEquals(Is n) {
        auto builder = module_.builder(n);

        auto op = n.negate ? Operator.COMPARE : Operator.BOOL_EQ;

        auto binary = builder.binary(op, n.left, n.right, TYPE_BOOL);

        resolver.fold(n, binary);
    }
    void rewriteToEnumMemberValues(Is n, Enum enum_) {
        auto builder = module_.builder(n);
        auto lemv    = builder.enumMemberValue(enum_, n.left());
        auto remv    = builder.enumMemberValue(enum_, n.right());

        n.add(lemv);
        n.add(remv);
        resolver.setModified();
    }
}