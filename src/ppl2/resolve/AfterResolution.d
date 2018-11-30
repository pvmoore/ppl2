module ppl2.resolve.AfterResolution;

import ppl2.internal;
///
/// These tasks need to be done after all nodes have been resolved
///
final class AfterResolution {
private:
    BuildState buildState;
public:
    this(BuildState buildState) {
        this.buildState = buildState;
    }
    void process(Module[] modules) {
        bool hasMainModule = buildState.mainModule !is null;
        Module mainModule  = buildState.mainModule;
        Function entry     = hasMainModule ? mainModule.getFunctions("main")[0] : null;

        auto calls = new DynamicArray!Call;

        foreach(mod; modules) {

            auto initFunc = mod.getInitFunction();
            auto initBody = initFunc.getBody();

            /// Move struct static var initialisers into module new()
            foreach(ns; mod.getStructsRecurse) {
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

            if(hasMainModule) {
                // todo - get this in the right order
                /// Call module init function at start of program entry
                auto call = mainModule.nodeBuilder.call("new", mod.getInitFunction());

                /// Arguments should always be the 1st child of body
                entry.getBody().insertAt(1, call);
            }
        }
    }
private:
}