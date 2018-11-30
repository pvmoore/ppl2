module ppl2.resolve.resolve_unary;

import ppl2.internal;

final class UnaryResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Unary n) {
        if(n.expr.getType.isStruct && n.op.isOverloadable) {
            /// Look for an operator overload
            string name = "operator" ~ n.op.value;

            /// Rewrite to operator overload:
            /// Unary
            ///     expr struct
            /// Dot
            ///     AddressOf
            ///         expr struct
            ///     Call
            ///
            auto b = module_.builder(n);

            auto left  = n.expr.getType.isValue ? b.addressOf(n.expr) : n.expr;
            auto right = b.call(name, null);

            auto dot = b.dot(left, right);

            resolver.fold(n, dot);
            return;
        }
        /// If expression is a const literal number then apply the
        /// operator and replace Unary with the result
        if(n.isResolved && n.isConst) {
            auto lit = n.expr().as!LiteralNumber;
            if(lit) {
                lit.value.applyUnary(n.op);
                lit.str = lit.value.getString();

                resolver.fold(n, lit);
                return;
            }
        }
    }
}
