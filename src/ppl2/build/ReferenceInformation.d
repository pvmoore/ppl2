module ppl2.build.ReferenceInformation;

import ppl2.internal;

final class ReferenceInformation {
private:
    BuildState buildState;
    Module[] modules;
    Target[][string] moduleTargets; /// all active targets within each module

    Set!int referencedModules;
    Set!int referencedVariables;
    Set!int referencedFunctions;
public:
    this(BuildState buildState) {
        this.buildState          = buildState;
        this.referencedModules   = new Set!int;
        this.referencedVariables = new Set!int;
        this.referencedFunctions = new Set!int;
    }
    bool isReferenced(Module m) {
        return referencedModules.contains(m.nid);
    }
    bool isReferenced(Variable v) {
        return referencedVariables.contains(v.nid);
    }
    bool isReferenced(Function f) {
        return referencedFunctions.contains(f.nid);
    }
    Module[] allReferencedModules() {
        return buildState.allModules()
                         .filter!(it=>referencedModules.contains(it.nid))
                         .array;
    }
    void process() {
        this.modules = buildState.allModules();

        foreach(m; modules) {
            Target[] targets;
            gatherActiveTargets(m, targets);

            moduleTargets[m.canonicalName] = targets;

            foreach(t; targets) {
                if(t.isVariable) {
                    referencedVariables.add(t.getVariable().nid);
                } else {
                    referencedFunctions.add(t.getFunction().nid);
                }
            }
        }
        gatherModuleReferences();
    }
private:
    void gatherActiveTargets(Module m, ref Target[] targets) {
        void extractTarget(ASTNode node) {
            if(node.id==NodeID.IDENTIFIER) {
                targets ~= node.as!Identifier.target;
            } else if(node.id==NodeID.CALL) {
                targets ~= node.as!Call.target;
            }
            foreach(ch; node.children) {
                extractTarget(ch);
            }
        }

        foreach(root; m.getCopyOfActiveRoots()) {
            extractTarget(root);
        }
    }
    void gatherModuleReferences() {
        auto mainModule = buildState.mainModule;
        assert(mainModule);

        auto processedModules = new Set!string;

        void handle(Module module_) {
            if(referencedModules.contains(module_.nid)) return;
            referencedModules.add(module_.nid);

            foreach(m; module_.getReferencedModules()) {
                handle(m);
            }
        }

        handle(mainModule);
    }
}