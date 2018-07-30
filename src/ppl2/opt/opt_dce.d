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

        /// Remove functions that are not referenced or are template blueprints
        auto functions = new Array!Function;
        module_.selectDescendents!Function(functions);
        foreach(f; functions) {
        //foreach(f; module_.getFunctions()) {
            if(f.isImport) {
                log("\t  proxy func %s", f.name);
                f.detach();
            } else if(f.isTemplateBlueprint) {
                log("\t  template func %s", f.name);
                f.detach();
            } else if(f.numRefs==0 && f.name!="new") {
                log("\t  unreferenced func %s", f);
                f.detach();
                /// If this function contains a call or identifier then deref them. Is that possible?
            }
        }
        /// Remove ALL Defines
        auto defines = new Array!Define;
        module_.selectDescendents!Define(defines);
        foreach(d; defines) {
            log("\t define %s", d.name);
            d.detach();
        }
        /// Remove named structs that are not referenced or are template blueprints
        auto namedStructs = new Array!NamedStruct;
        module_.selectDescendents!NamedStruct(namedStructs);
        foreach(ns; namedStructs) {
            if(ns.isTemplateBlueprint) {
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
        /// Remove ALL imports
        auto imports = new Array!Import;
        module_.selectDescendents!Import(imports);
        foreach(imp; imports) {
            log("\t import %s", imp.moduleName);
            imp.detach();
        }
    }
}