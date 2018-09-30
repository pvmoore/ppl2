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

            auto initFunc = mod.getInitFunction();
            auto initBody = initFunc.getBody();

            /// Move static var initialisers into module new()
            foreach(ns; mod.getAllNamedStructs) {
                foreach_reverse(v; ns.getStaticVariables) {
                    if(v.hasInitialiser) {
                        initBody.insertAt(1, v.initialiser);
                    }
                }
            }
            /// Move global var initialisers into module new()
            foreach_reverse(v; mod.getVariables()) {
                if(v.hasInitialiser) {
                    /// Arguments should always be the 1st child of body so we insert at 1
                    initBody.insertAt(1, v.initialiser);
                }
            }

            // todo - get this in the right order
            /// Call module init function at start of program entry
            auto call = mainModule.nodeBuilder.call("new", mod.getInitFunction());

            /// Arguments should always be the 1st child of body
            entry.getBody().insertAt(1, call);
        }
    }
private:
}