module ppl2.resolve.resolve_builtinfunc;

import ppl2.internal;

final class BuiltinFuncResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(BuiltinFunc n) {

        if(!n.exprTypes().areKnown) return;

        int expectedNumExprs = 1;
        switch(n.name) {
            case "#sizeof":
                if(n.numExprs > 0) {
                    int size = n.exprs()[0].getType().size();
                    resolver.fold(n, LiteralNumber.makeConst(size, TYPE_INT));
                }
                break;
            case "#typeof":
                if(n.numExprs > 0) {
                    auto t = n.exprs()[0].getType;
                    resolver.fold(n, TypeExpr.make(t));
                }
                break;
            case "#initof":
                if(n.numExprs > 0) {
                    auto ini = initExpression(n.exprs()[0].getType);
                    resolver.fold(n, ini);
                }
                break;
            case "#isptr":
                if(n.numExprs > 0) {
                    auto r = n.exprTypes()[0].isPtr;
                    resolver.fold(n, LiteralNumber.makeConst(r, TYPE_BOOL));
                }
                break;
            case "#isvalue":
                if(n.numExprs > 0) {
                    auto r = n.exprTypes()[0].isPtr;
                    resolver.fold(n, LiteralNumber.makeConst(!r, TYPE_BOOL));
                }
                break;
            default:
                assert(false);
        }

        if(n.numExprs != expectedNumExprs) {
            module_.addError(n, "Expecting %s expressions".format(expectedNumExprs), true);
        }
    }
}