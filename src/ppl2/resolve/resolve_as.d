module ppl2.resolve.resolve_as;

import ppl2.internal;

final class AsResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(As n) {
        auto lt      = n.leftType();
        auto rt      = n.rightType();
        auto builder = module_.builder(n);

        if(!lt.isKnown || !rt.isKnown) return;

        /// If cast is unnecessary then just remove the As
        if(lt.exactlyMatches(rt)) {
            resolver.fold(n, n.left);
            return;
        }

        /// enum as enum (they must be different enums because they didn't exactly match)
        if(lt.isEnum && rt.isEnum) {
            /// eg. A::VAL as B
            /// Create new EnumMember
            auto enum_  = rt.getEnum;
            auto value  = builder.enumMemberValue(enum_, n.left());
            //auto value  = builder.dot(n.left(), builder.identifier("value"));
            auto member = builder.enumMember(enum_, value);

            resolver.fold(n, member);
            return;
        }

        /// enum as non-enum
        if(lt.isEnum && !rt.isEnum) {
            /// Rewrite to left.value as right

            auto value = builder.enumMemberValue(lt.getEnum, n.left());

            //auto dot = builder.dot(n.left(), builder.identifier("value"));

            n.addToFront(value);

            resolver.setModified();
            return;
        }

        /// non-enum as enum
        if(!lt.isEnum && rt.isEnum) {
            /// Create new EnumMember
            auto member = builder.enumMember(rt.getEnum, n.left());

            resolver.fold(n, member);
            return;
        }

        /// If left is a literal number then do the cast now
        auto lit = n.left().as!LiteralNumber;
        if(lit && rt.isValue) {

            lit.value.as(rt);
            lit.str = lit.value.getString();

            resolver.fold(n, lit);
            return;
        }

        bool isValidRewrite(Type t) {
            return t.isValue && (t.isTuple || t.isArray || t.isStruct);
        }

        if(isValidRewrite(lt) && isValidRewrite(rt)) {
            if(!lt.exactlyMatches(rt)) {
                /// Tuple value -> Tuple value

                /// This is a reinterpret cast

                /// Rewrite:
                ///------------
                /// As
                ///    left
                ///    right
                ///------------
                /// ValueOf type=rightType
                ///    As
                ///       AddressOf
                ///          left
                ///       AddressOf
                ///          right

                auto p = n.parent;

                auto value = makeNode!ValueOf(n);

                resolver.fold(n, value);

                auto left  = builder.addressOf(n.left);
                auto right = builder.addressOf(n.right);
                n.add(left);
                n.add(right);

                value.add(n);

                return;
            }
        }
    }
}