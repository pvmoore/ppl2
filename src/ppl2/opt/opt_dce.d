module ppl2.opt.opt_dce;

import ppl2.internal;
///
/// Remove any nodes that do not affect the result. ie. they are not referenced
///
/// Todo:
///     Remove unreferenced Modules
///     Remove calls that call a function with nothing in it
///     Remove Functions that are not called
///
/// Maybe merge this back into ModuleConstantFolder
///
final class OptimisationDCE {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_     = module_;
    }

    void opt() {
        log("Removing dead nodes from module %s", module_.canonicalName);

        /// Look at module scope functions that are not referenced
        foreach(f; module_.getFunctions()) {
            if(f.isImport) {
                log("\t  proxy func %s", f.name);
                f.detach();
            } else if(f.numRefs==0 && f.name!="new") {
                log("\t  unreferenced func %s", f);
                f.detach();
                /// If this function contains a call or identifier then deref them. Is that possible?
            }
        }
        /// Look at module scope defines that are not referenced
        foreach(d; module_.getDefines()) {
            if(d.isImport ) {
                log("\t  proxy define %s", d.name);
                d.detach();
            } else if(d.numRefs==0) {
                log("\t  unreferenced define %s", d.name);
                d.detach();
            }
        }
        /// Look at module scope defines that are not referenced
        foreach(d; module_.getNamedStructs()) {
            if(d.numRefs==0) {
                log("\t  unreferenced named struct %s", d.name);
                d.detach();
            }
        }
    }
    //===================================================================================
    void visit(Module n) {
        if(n.nid == g_mainModuleNID) return;

        if(n.numRefs==0) {
            // todo
        }
    }
    void visit(Variable n) {
        if(!isAttached(n)) return;

        if(n.numRefs==0 && n.isLocal && !n.isParameter) {
            /// No references to this local variable

            if(n.hasInitialiser) {
                //auto array = new Array!Identifier;
                //n.selectDescendents!Identifier(array);
                //foreach(id; array) {
                //    id.target.dereference();
                //}
                auto ini = n.initialiser();
                bool isSafeToRemove = ini.isA!LiteralNumber || ini.isA!LiteralNull;

                if(!isSafeToRemove) {
                    /// Assume for the moment that we can't remove this Variable
                    return;
                }
            } else {
                /// No initialiser and no refs
            }

            n.parent.remove(n);
            return;
        }
    }
    void visit(Function n) {
        if(!isAttached(n)) return;

        if(n.numRefs==0) {
            // todo
        }
    }
//===========================================================================================
private:
    bool isAttached(ASTNode n) {
        if(n.parent is null) return false;
        if(n.parent.isModule) return true;
        return isAttached(n.parent);
    }
}