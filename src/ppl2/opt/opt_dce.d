module ppl2.opt.opt_dce;

import ppl2.internal;
///
/// Remove any nodes that do not affect the result. ie. they are not referenced
///
final class OptimisationDCE {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
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
        /// Remove all Defines
        auto defines = new Array!Define;
        module_.selectDescendents!Define(defines);
        foreach(d; defines) {
            //if(d.isTemplateProxy) {
            //    log("\t  template proxy define %s", d.name);
            //    d.detach();
            //} else if(d.isImport ) {
            //    log("\t  proxy define %s", d.name);
            //    d.detach();
            //} else if(d.numRefs==0) {
            //    log("\t  unreferenced define %s", d.name);
            //    d.detach();
            //} else {
                log("\t define %s", d.name);
                d.detach();
            //}
        }
        /// Look at named structs that are not referenced or are template blueprints
        auto namedStructs = new Array!NamedStruct;
        module_.selectDescendents!NamedStruct(namedStructs);
        foreach(ns; namedStructs) {
            if(ns.isTemplate) {
                log("\t  template blueprint named struct %s", ns.name);
                ns.detach();
            } else if(ns.numRefs==0) {
                log("\t  unreferenced named struct %s", ns.name);
                ns.detach();
            } else {
                /// The struct is referenced but some of the functions may not be
                foreach(f; ns.type.getMemberFunctions()) {
                    if(f.numRefs==0) {
                        log("\t  unreferenced func %s.%s", ns.name, f.name);
                        f.detach();
                    }
                }
            }
        }
    }
}