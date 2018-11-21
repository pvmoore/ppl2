module ppl2.resolve.resolve_enum;

import ppl2.internal;

final class EnumResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Enum n) {

        if(!n.elementType.isKnown) return;

        if(n.elementType.isVoid && n.elementType.isValue) {
            module_.addError(n, "Enum values cannot be void", true);
            return;
        }
        if(n.numChildren==0) {
            module_.addError(n, "Enums cannot be empty", true);
            return;
        }

        setImplicitValues(n);
    }
private:
    void setImplicitValues(Enum n) {

        /// Set any unset values
        int value = 0;

        foreach(em; n.members()) {

            if(em.hasChildren) {
                auto expr = em.expr();

                /// We need this to be resolved or we can't continue
                if(!expr.isResolved) return;

                /// Assume it is a LiteralNumber for now
                auto lit = expr.as!LiteralNumber;
                assert(lit);

                value = lit.value.getInt();
            } else {
                /// Add implicit value

                if(!n.elementType.isBasicType || n.elementType.isPtr) {
                    module_.addError(n, "Enum type %s must have explicit initialisers".format(n.elementType), true);
                    return;
                }

                auto lit = LiteralNumber.makeConst(value, n.elementType);
                em.add(lit);

                resolver.setModified();
            }

            value++;
        }
    }
}