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
        }

        addModuleConstructorCalls();
    }
private:
    void addModuleConstructorCalls() {
        if(buildState.mainModule is null) return;

        Module mainModule = buildState.mainModule;
        Function entry    = mainModule.getFunctions("main")[0];

        alias comparator = (Module a, Module b) {
            return a.getPriority < b.getPriority;
        };

        auto builder = mainModule.builder(entry);

        foreach_reverse(mod; buildState.allModules.sort!(comparator)) {
            //writefln("[%s] %s", mod.getPriority, mod.canonicalName);

            auto call = builder.call("new", mod.getInitFunction());

            /// Add after Parameters and call to GC.start()
            entry.getBody().insertAt(2, call);
        }

        assert(entry.getBody().first().isA!Parameters);
        assert(entry.getBody().children[1].isA!Dot &&
               entry.getBody().children[1].as!Dot.right().isA!Call &&
               entry.getBody().children[1].as!Dot.right().as!Call.name=="start");
    }
}