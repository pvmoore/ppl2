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
    ///
    /// Find the first variable or function that matches the given identifier name.
    ///
    Result findFirst(string name, ASTNode node) {
        Result res;
        auto nid = node.id();

        switch(nid) with(NodeID) {
            case FUNCTION:
                if(node.as!Function.name==name) res.set(node.as!Function);
                break;
            case VARIABLE:
                if(node.as!Variable.name==name) res.set(node.as!Variable);
                break;
            case MODULE:
                /// Check all module level variables
                foreach(n; node.children) {
                    isThisIt(name, n, res);
                    if(res.found) return res;
                }
                /// We can't find it
                return res;
            case ANON_STRUCT:
                /// Check all struct level variables
                foreach(n; node.children) {
                    isThisIt(name, n, res);
                    if(res.found) return res;
                }

                /// Skip to module level scope
                return findFirst(name, node.getModule());
            case LITERAL_FUNCTION:
                /// If this is not a closure
                if(!node.as!LiteralFunction.isClosure) {
                    /// Go to containing struct if there is one
                    auto struct_ = node.getContainingStruct();
                    if(struct_) return findFirst(name, struct_);
                }

                /// Go to module scope
                return findFirst(name, node.getModule());
            default:
                break;
        }
        if(res.found) return res;

        /// Check variables that appear before this in the tree
        foreach(n; node.prevSiblings()) {
            isThisIt(name, n, res);
            if(res.found) return res;
        }
        /// Recurse up the tree
        return findFirst(name, node.parent);
    }
private:
    void isThisIt(string name, ASTNode n, ref Result res) {
        switch(n.id) with(NodeID) {
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
}