module ppl2.resolve.after_resolution;

import ppl2.internal;
///
/// These tasks need to be done after all nodes have been resolved
///
final class AfterResolution {
private:
    Module[] modules;
public:
    this(Module[] modules) {
        this.modules = modules;
    }

    void process() {
        auto mainModule = PPL2.mainModule();
        auto entry      = mainModule.getFunctions("main")[0];
        assert(entry);

        auto calls = new Array!Call;

        foreach(mod; modules) {

            /// Move global var initialisers to module new()
            auto initFunc = mod.getInitFunction();
            foreach_reverse(v; mod.getVariables()) {
                if(v.hasInitialiser) {
                    /// Arguments should always be the 1st child of body
                    initFunc.getBody().insertAt(1, v.initialiser);
                }
            }

            // todo - get this in the right order
            /// Call module init function at start of program entry
            auto call = mainModule.nodeBuilder.call("new", mod.getInitFunction());

            /// Arguments should always be the 1st child of body
            entry.getBody().insertAt(1, call);


            /// Rewrite calls to member functions
            calls.clear();
            mod.selectDescendents!Call(calls);
            foreach(c; calls) {
                rewriteCallToMemberFunction(c);
            }
        }
    }

private:
    /// Add implicit this* arg to call to struct member function.
    ///
    /// Move ID to first call argument
    /// Put TypeExpr node into its original position
    ///
    /// Dot
    ///    ID ------    (replace with TypeExpr)
    ///    Call    |
    ///       ID <--
    ///
    void rewriteCallToMemberFunction(Call n) {

        if(n.target.isMemberFunction && n.name!="new") {
            auto dot   = n.parent.as!Dot;
            auto id    = n.prevSibling();
            auto dummy = TypeExpr.make(id.getType);
            assert(dot);
            assert(id);

            dot.replaceChild(id, dummy);

            if(id.getType.isValue) {
                auto ptr = makeNode!AddressOf;
                ptr.addToEnd(id);
                n.insertAt(0, ptr);
            } else {
                n.insertAt(0, id);
            }
        }
    }
}