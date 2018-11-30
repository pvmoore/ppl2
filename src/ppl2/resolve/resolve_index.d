module ppl2.resolve.resolve_index;

import ppl2.internal;

final class IndexResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Index n) {
        if(n.exprType().isStruct) {
            /// Rewrite this to a call to operator[]

            auto ns = n.exprType.getStruct;

            auto b = module_.builder(n);

            if(n.parent.isBinary) {
                auto bin = n.parent.as!Binary;
                if(bin.op.isAssign && n.nid==bin.left.nid) {
                    /// Rewrite to operator:(int,value)

                    /// Binary =
                    ///     Index
                    ///         index
                    ///         struct
                    ///     expr
                    ///....................
                    /// Dot
                    ///     [AddressOf] struct
                    ///     Call
                    ///         index
                    ///         expr
                    auto left = n.exprType.isValue ? b.addressOf(n.expr) : n.expr;
                    auto call = b.call("operator[]", null)
                                 .add(n.index)
                                 .add(bin.right);

                    auto dot = b.dot(left, call);

                    resolver.fold(bin, dot);
                    return;
                }
            }
            /// Rewrite to operator:(int)

            /// Index
            ///     struct
            ///     index
            ///.............
            /// Dot
            ///     [AddressOf] struct
            ///     Call
            ///         index
            auto left = n.exprType.isValue ? b.addressOf(n.expr) : n.expr;
            auto call = b.call("operator[]", null)
                         .add(n.index);

            auto dot = b.dot(left, call);

            resolver.fold(n, dot);
            return;

        }
    }
}