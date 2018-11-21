module ppl2.resolve.resolve_if;

import ppl2.internal;

final class IfResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(If n) {
        if(!n.isResolved) {
            if(!n.isExpr) {
                n.type = TYPE_VOID;
                return;
            }
            if(!n.hasThen) {
                n.type = TYPE_VOID;
                return;
            }

            auto thenType = n.thenType();
            Type elseType = n.hasElse ? n.elseType() : TYPE_UNKNOWN;

            if(thenType.isUnknown) {
                return;
            }

            if(n.hasElse) {
                if(elseType.isUnknown) return;

                auto t = getBestFit(thenType, elseType);
                if(!t) {
                    module_.addError(n, "If result types %s and %s are incompatible".format(thenType, elseType), true);
                }

                n.type = t;

            } else {
                n.type = thenType;
            }
        }
    }
}