module ppl2.opt.opt_dead_code;

import ppl2.internal;
///
/// Remove any nodes that do not affect the result. ie. they are not referenced
///
final class DeadCodeEliminator {
private:
    Module module_;
    StopWatch watch;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    void clearState() {
        watch.reset();
    }

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    void opt() {
        watch.start();
        log("Removing dead nodes from module %s", module_.canonicalName);

        /// Remove functions that are not referenced or are template blueprints
        auto functions = new DynamicArray!Function;
        module_.selectDescendents!Function(functions);
        foreach(f; functions) {
            if(f.isImport) {
                log("\t  proxy func %s", f.name);
                remove(f);
            } else if(f.isTemplateBlueprint) {
                log("\t  template func %s", f.name);
                remove(f);
            } else if(f.numRefs==0 && f.name!="new") {
                log("\t  unreferenced func %s", f);
                remove(f);
            }
        }

        /// Remove ALL Aliases
        auto aliases = new DynamicArray!Alias;
        module_.selectDescendents!Alias(aliases);
        foreach(a; aliases) {
            log("\t alias %s", a.name);
            remove(a);
        }

        /// Remove unused Enums and all EnumMembers whether used or not
        auto enums = new DynamicArray!Enum;
        module_.selectDescendents!Enum(enums);
        foreach(e; enums) {
            if(e.numRefs==0) {
                remove(e);
            }
        }

        /// Remove named structs that are not referenced or are template blueprints
        auto namedStructs = new DynamicArray!Struct;
        module_.selectDescendents!Struct(namedStructs);
        foreach(ns; namedStructs) {
            if(ns.isTemplateBlueprint) {
                log("\t  template blueprint named struct %s", ns.name);
                remove(ns);
            } else if(ns.numRefs==0) {
                log("\t  unreferenced named struct %s", ns.name);
                remove(ns);
            } else {
                /// The struct is referenced but some of the functions may not be
                foreach(f; ns.getMemberFunctions()) {
                    if(f.numRefs==0) {
                        log("\t  unreferenced func %s.%s", ns.name, f.name);
                        remove(f);
                    }
                }
            }
        }

        /// Remove ALL imports
        auto imports = new DynamicArray!Import;
        module_.selectDescendents!Import(imports);
        foreach(imp; imports) {
            log("\t import %s", imp.moduleName);
            remove(imp);
        }

        /// Remove asserts
        if(!module_.config.enableAsserts) {
            module_.recurse!Assert((n) {
                n.detach();
            });
        }

        /// Unreferenced module scope variables
        foreach(v; module_.getVariables()) {
            if(v.numRefs==0) {
                v.detach();
            }
        }

        watch.stop();
    }
private:
    ///
    /// Detach this function from the AST.
    ///
    /// Scan through the child nodes and in the case of:
    ///     - Call       : dereference
    ///     - Identifier : dereference
    ///     - Closure    : remove
    ///
    void remove(Function f) {

        f.recurse!Call(it=>it.target.dereference());
        f.recurse!Identifier(it=>it.target.dereference());

        f.recurse!Closure(it=>
            module_.removeClosure(it)
        );

        f.detach();
    }
    void remove(Alias a) {
        a.detach();
    }
    void remove(Struct n) {
        n.detach();
    }
    void remove(Enum e) {
        e.detach();
    }
    void remove(EnumMember e) {
        e.detach();
    }
    void remove(Import i) {
        i.detach();
    }
}