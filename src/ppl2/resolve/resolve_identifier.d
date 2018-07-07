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
    ///
    /// Find the first variable that matches the given identifier name.
    ///
    Variable findFirstVariable(string name, ASTNode node) {
        //writefln("findFirstVariable node=%s parent=%s", node, node.parent); flushConsole();
        auto nid = node.id();

        switch(nid) with(NodeID) {
            case VARIABLE:
                if(node.as!Variable.name==name) return node.as!Variable;
                break;
            default:
                break;
        }

        if(nid==NodeID.MODULE) {
            /// Check all module level variables
            foreach(n; node.children) {
                auto v = isThisTheVar(name, n);
                if(v) return v;
            }
            /// We can't find it
            return null;
        }

        if(nid==NodeID.ANON_STRUCT) {
            /// Check all struct level variables
            foreach(n; node.children) {
                auto v = isThisTheVar(name, n);
                if(v) return v;
            }

            /// Skip to module level scope
            return findFirstVariable(name, node.getModule());
        }

        if(nid==NodeID.LITERAL_FUNCTION) {

            /// If this is not a closure
            if(!node.as!LiteralFunction.isClosure) {
                /// Go to containing struct if there is one
                auto struct_ = node.getContainingStruct();
                if(struct_) return findFirstVariable(name, struct_);
            }

            /// Go to module scope
            return findFirstVariable(name, node.getModule());
        }

        /// Check variables that appear before this in the tree
        foreach(n; node.prevSiblings()) {
            auto v = isThisTheVar(name, n);
            if (v) return v;
        }
        /// Recurse up the tree
        return findFirstVariable(name, node.parent);

    }
private:
    Variable isThisTheVar(string name, ASTNode n) {
        auto v = cast(Variable)n;
        if(v && v.name==name) {
            return v;
        }
        auto params = n.as!Parameters;
        if(params) {
            return params.getParam(name);

        }
        return null;
    }
}