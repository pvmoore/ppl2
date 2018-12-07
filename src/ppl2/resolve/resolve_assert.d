module ppl2.resolve.resolve_assert;

import ppl2.internal;

final class AssertResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Assert n) {

        if(!n.isResolved) {

            /// This should be imported implicitly
            assert(findImportByCanonicalName("core::assert", n));

            /// Wait until we know what the type is
            Type type = n.expr().getType();
            if(type.isUnknown) return;

            /// Convert to a call to __assert(bool, string, int)
            auto parent = n.parent;
            auto b      = module_.builder(n);

            auto c = b.call("__assert", null);

            resolver.fold(n, c);

            /// value
            Expression value;
            if(type.isPtr) {
                value = b.binary(Operator.COMPARE, n.expr(), LiteralNull.makeConst(type));
            } else if(type.isBool) {
                value = n.expr();
            } else {
                value = b.binary(Operator.COMPARE, n.expr(), LiteralNumber.makeConst(0));
            }
            c.add(value);

            /// string
            //c.add(b.string_(module_.moduleNameLiteral));
            c.add(module_.moduleNameLiteral.copy());

            /// line
            c.add(LiteralNumber.makeConst(n.line+1, TYPE_INT));

            return;
        }
        /// If the asserted expression is now a const number then
        /// evaluate it now and replace the assert with a true or false
        if(n.expr().isResolved) {
            auto lit = n.expr().as!LiteralNumber;
            if(lit) {
                if(lit.value.getBool()==false) {
                    module_.addError(n, "Assertion failed", true);
                    return;
                }

                resolver.fold(n, lit);
            }
        }
    }
}