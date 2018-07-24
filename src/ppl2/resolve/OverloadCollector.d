module ppl2.resolve.OverloadCollector;

import ppl2.internal;

final class OverloadCollector {
    private:
    Array!Callable results;
    bool includeTemplates;
    string name;
    bool ready;
    public:
    ///
    /// Find any function or variable that matches the given name.
    ///
    /// Return true - if results contains the full overload set and all types are known,
    ///       false - if we are waiting for imports or some types are waiting to be known.
    ///
    bool collect(string name, ASTNode startNode, Array!Callable results, bool includeTemplates) {
        this.name             = name;
        this.ready            = true;
        this.results          = results;
        this.includeTemplates = includeTemplates;
        this.results.clear();
        subCollect(startNode);
        return ready;
    }
    private:
    void subCollect(ASTNode node) {
        auto nid = node.id();

        if(nid==NodeID.MODULE) {
            /// Check all module level variables/functions
            foreach(n; node.children) {
                check(n);
            }
            return;
        }

        if(nid==NodeID.ANON_STRUCT) {
            /// Check all struct level variables
            foreach(n; node.children) {
                check(n);
            }

            /// Skip to module level scope
            subCollect(node.getModule());
            return;
        }

        if(nid==NodeID.LITERAL_FUNCTION) {

            /// If this is not a closure
            if(!node.as!LiteralFunction.isClosure) {
                /// Go to containing struct if there is one
                auto struct_ = node.getContainingStruct();
                if(struct_) return subCollect(struct_);
            }

            /// Go to module scope
            subCollect(node.getModule());
            return;
        }

        /// Check variables that appear before this in the tree
        foreach(n; node.prevSiblings()) {
            check(n);
        }
        /// Recurse up the tree
        subCollect(node.parent);
    }
    void check(ASTNode n) {
        auto v    = n.as!Variable;
        auto f    = n.as!Function;
        auto comp = n.as!Composite;

        if(v && v.name==name) {
            if(v.type.isUnknown) ready = false;
            results.add(Callable(v));
        } else if(f && f.name==name) {
            if(f.isImport) {
                auto m = PPL2.getModule(f.moduleName);
                if(m && m.isParsed) {
                    auto fns = m.getFunctions(name);
                    if(fns.length==0) {
                        /// Assume it will turn up later
                        ready = false;
                        return;
                    }
                    foreach(fn; fns) {
                        addFunction(fn);
                    }
                } else {
                    /// Bring the import in and start parsing it
                    functionRequired(f.moduleName, name);
                    ready = false;
                }
            } else {
                addFunction(f);
            }
        } else if(comp) {
            foreach(ch; comp.children[]) {
                check(ch);
            }
        }
    }
    void addFunction(Function f) {
        if(f.isTemplate) {
            if(includeTemplates) {
                ready = false;
                results.add(Callable(f));
            }
        } else {
            if(f.getType.isUnknown) {
                ready = false;
            }
            functionRequired(f.moduleName, name);
            results.add(Callable(f));
        }
    }
}