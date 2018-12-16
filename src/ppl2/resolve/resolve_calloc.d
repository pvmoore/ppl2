module ppl2.resolve.resolve_calloc;

import ppl2.internal;

final class CallocResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Calloc n) {
        resolver.resolveAlias(n, n.valueType);

        if(n.valueType.isKnown) {
            /// Rewrite Calloc to:

            /// As
            ///     Dot
            ///         GC
            ///         call calloc
            ///             size
            ///     TypeExpr

            auto b = module_.builder(n);

            auto dot = b.callStatic("GC", "calloc", n);
            dot.second().add(b.integer(n.valueType.size));

            auto as = b.as(dot, n.getType);

            resolver.fold(n, as);
        }
    }
}