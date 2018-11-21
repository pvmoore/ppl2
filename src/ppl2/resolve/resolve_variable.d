module ppl2.resolve.resolve_variable;

import ppl2.internal;

final class VariableResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Variable n) {

        resolver.resolveAlias(n, n.type);

        if(n.type.isUnknown) {

            if(n.isParameter) {
                /// If we are a closure inside a call
                auto call = n.getAncestor!Call;
                if(call && call.isResolved) {

                    auto params = n.parent.as!Parameters;
                    assert(params);

                    auto callIndex = call.indexOf(n);

                    auto ptype = call.target.paramTypes[callIndex];
                    if(ptype.isFunction) {
                        auto idx = params.getIndex(n);
                        assert(idx!=-1);

                        if(idx<ptype.getFunctionType.paramTypes.length) {
                            auto t = ptype.getFunctionType.paramTypes[idx];
                            n.setType(t);
                        }
                    }
                }
            }

            if(n.hasInitialiser) {
                /// Get the type from the initialiser
                if(n.initialiserType().isKnown) {
                    n.setType(n.initialiserType());
                }

            } else {
                /// No initialiser

            }
        }
        if(n.type.isKnown) {
            /// Ensure the function ptr matches the closure type
            if(n.isFunctionPtr && n.hasInitialiser) {
                auto lf = n.getDescendent!LiteralFunction;
                if(lf) {
                    lf.type = n.type;
                }
            }
        }
    }
}