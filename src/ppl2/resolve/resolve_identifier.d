module ppl2.resolve.resolve_identifier;

import ppl2.internal;
///
/// Resolve an identifier.
/// All identifiers must be found within the same module.
///
final class IdentifierResolver {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    struct Result {
        union {
            Variable var;
            Function func;
        }
        bool isVar;
        bool isFunc;

        void set(Variable v) {
            this.var   = v;
            this.isVar = true;
        }
        void set(Function f) {
            this.func   = f;
            this.isFunc = true;
        }

        bool found() { return isVar || isFunc; }
    }
    ///==================================================================================
    Result find(string name, ASTNode node) {
        Result res;

        /// Check previous siblings at current level
        foreach(n; node.prevSiblings()) {
            isThisIt(name, n, res);
            if(res.found) return res;
        }

        /// Recurse up the tree
        findRecurse(name, node.parent, res);

        return res;
    }
private:
    ///==================================================================================
    void findRecurse(string name, ASTNode node, ref Result res) {

        isThisIt(name, node, res);
        if(res.found) return;

        auto nid = node.id();

        switch(nid) with(NodeID) {
            case MODULE:
            case ANON_STRUCT:
            case NAMED_STRUCT:
                /// Check all variables at this level
                foreach(n; node.children) {
                    isThisIt(name, n, res);
                    if(res.found) return;
                }
                if(nid==MODULE) return;
                break;
            case LITERAL_FUNCTION:
                if(!node.as!LiteralFunction.isClosure) {
                    /// Go to containing struct if there is one
                    auto ns = node.getAncestor!NamedStruct();
                    if(ns) {
                        findRecurse(name, ns, res);
                        return;
                    }
                }
                /// Go to module scope
                findRecurse(name, node.getModule(), res);
                return;
            default:
                break;
        }

        /// Check variables that appear before this in the tree
        foreach(n; node.prevSiblings()) {
            isThisIt(name, n, res);
            if(res.found) return;
        }

        findRecurse(name, node.parent, res);
    }
    void isThisIt(string name, ASTNode n, ref Result res) {

        switch(n.id) with(NodeID) {
            case COMPOSITE:
                /// Treat children of Composite as if they were in scope
                foreach(n2; n.children) {
                    isThisIt(name, n2, res);
                    if(res.found) break;
                }
                break;
            case VARIABLE: {
                auto v = n.as!Variable;
                if(v.name==name) res.set(v);
                break;
            }
            case PARAMETERS: {
                auto v = n.as!Parameters.getParam(name);
                if(v) res.set(v);
                break;
            }
            case FUNCTION: {
                auto f = n.as!Function;
                if(f.name==name) res.set(f);
                break;
            }
            default:
                break;
        }
    }
    void chat(A...)(lazy string fmt, lazy A args) {
        //if(module_.canonicalName=="test_variables") {
        //    dd(format(fmt, args));
        //}
    }
}