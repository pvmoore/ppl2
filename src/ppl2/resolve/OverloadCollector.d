module ppl2.resolve.OverloadCollector;

import ppl2.internal;

final class OverloadCollector {
private:
    Module module_;
    Array!Callable results;
    string name;
    bool ready;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    ///
    /// Find any function or variable that matches the given name.
    ///
    /// Return true - if results contains the full overload set and all types are known,
    ///       false - if we are waiting for imports or some types are waiting to be known.
    ///
    bool collect(Call call, ModuleAlias modAlias, Array!Callable results) {
        this.name     = call.name;
        this.ready    = true;
        this.results  = results;
        this.results.clear();

        if(modAlias) {
            subCollect(modAlias.imp);
        } else {
            subCollect(call);
        }
        return ready && module_.isParsed;
    }
private:
    /// Collect from an aliased import
    void subCollect(Import imp) {
        foreach(f; imp.getFunctions(name)) {
            check(f);
        }
    }
    void subCollect(ASTNode node) {
        auto nid = node.id();
        //dd("nid=", nid);

        if(nid==NodeID.MODULE) {
            /// Check all module level variables/functions
            foreach(n; node.children) {
                check(n);
            }
            return;
        }

        if(nid==NodeID.ANON_STRUCT || nid==NodeID.NAMED_STRUCT) {
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
                auto struct_ = node.getAncestor!AnonStruct();
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
        switch(n.id) with(NodeID) {
            case VARIABLE:
                auto v = n.as!Variable;
                if(v.name==name) {
                    if(v.type.isUnknown) ready = false;
                    results.add(Callable(v));
                }
                break;
            case FUNCTION:
                auto f = n.as!Function;
                if(f.name==name) {
                    if(f.isImport) {
                        auto m = module_.buildState.getOrCreateModule(f.moduleName);
                        if(m.isParsed) {
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
                            ready = false;
                        }
                    } else {
                        addFunction(f);
                    }
                }
                break;
            case COMPOSITE:
                auto comp = n.as!Composite;
                foreach(ch; comp.children[]) {
                    check(ch);
                }
                break;
            case IMPORT:
                auto imp = n.as!Import;
                /// Ignore alias imports
                if(imp.hasAliasName) break;
                foreach(ch; imp.children[]) {
                    check(ch);
                }
                break;
            case PARAMETERS:
                auto params = n.as!Parameters;
                foreach(ch; params.children[]) {
                    check(ch);
                }
                break;
            default:
                break;
        }
    }
    void addFunction(Function f) {
        if(f.isTemplateBlueprint) {
            results.add(Callable(f));
        } else {
            if(f.getType.isUnknown) {
                ready = false;
            }
            module_.buildState.functionRequired(f.moduleName, name);
            results.add(Callable(f));
        }
    }
}
