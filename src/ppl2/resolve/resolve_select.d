module ppl2.resolve.resolve_select;

import ppl2.internal;

final class SelectResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Select n) {
        if(!n.isResolved) {

            Type[] types = n.casesIncludingDefault().map!(it=>it.getType).array;

            if(!types.areKnown) {
                /// Allow cases to resolve if possible
                if(!resolver.isStalemate) return;

                /// Stalemate situation. Choose a type from the clauses that are resolved
                types = types.filter!(it=>it.isKnown).array;
            }

            auto type = getBestFit(types);
            if(type) {
                n.type = type;
            }
        }
        if(n.isResolved && !n.isSwitch) {
            ///
            /// Convert to a series of if/else
            ///
            auto cases = n.cases();
            auto def   = n.defaultStmts();

            /// Exit if this select is badly formed. This will already be an error
            if(cases.length==0 || def is null) return;

            If first;
            If prev;

            foreach(c; n.cases()) {
                If if_ = makeNode!If(n);
                if(first is null) first = if_;

                if(prev) {
                    /// else
                    auto else_ = Composite.make(n, Composite.Usage.PERMANENT);
                    else_.add(if_);
                    prev.add(else_);
                }

                /// No inits
                if_.add(Composite.make(n, Composite.Usage.PERMANENT));

                /// Condition
                if_.add(c.cond());

                /// then
                if_.add(c.stmts());

                prev = if_;
            }
            /// Final else
            assert(first);
            assert(prev);
            prev.add(def);

            resolver.fold(n, first);
            return;
        }
        if(n.isSwitch && n.valueType().isKnown) {
            /// If value type is bool then change it to int
            if(n.valueType.isBool) {

                auto val = n.valueExpr();
                auto as  = makeNode!As(n);

                resolver.fold(val, as);

                as.add(val);
                as.add(TypeExpr.make(TYPE_INT));
                return;
            }
        }
    }
}