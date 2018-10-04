module ppl2.gen.gen_variable;

import ppl2.internal;

void generateLocalGlobalVariableDeclarations(Module module_) {
    foreach(v; module_.getVariables()) {
        auto g = module_.llvmValue.addGlobal(v.type.getLLVMType(), v.name);
        g.setInitialiser(constAllZeroes(v.type.getLLVMType()));

        if(v.isStatic && !v.access.isPrivate) {
            g.setLinkage(LLVMLinkage.LLVMLinkOnceODRLinkage);
        } else {
            g.setLinkage(LLVMLinkage.LLVMInternalLinkage);
        }
        v.llvmValue = g;
    }
}
void generateLocalStaticVariableDeclarations(Module module_) {
    foreach(ns; module_.getNamedStructsRecurse) {
        foreach(v; ns.getStaticVariables) {
            string name = "%s::%s".format(ns.getUniqueName, v.name);
            auto g = module_.llvmValue.addGlobal(v.type.getLLVMType(), name);
            g.setInitialiser(constAllZeroes(v.type.getLLVMType()));
            g.setLinkage(LLVMLinkage.LLVMLinkOnceODRLinkage);
            v.llvmValue = g;
        }
    }
}
void generateImportedStaticVariableDeclarations(Module module_) {
    foreach(ns; module_.getImportedNamedStructs()) {
        foreach(v; ns.getStaticVariables()) {
            if(v.access.isPrivate) continue;

            string name = "%s::%s".format(ns.getUniqueName, v.name);
            auto g = module_.llvmValue.addGlobal(v.type.getLLVMType(), name);
            g.setInitialiser(undef(v.type.getLLVMType()));
            g.setLinkage(LLVMLinkage.LLVMAvailableExternallyLinkage);
            v.llvmValue = g;
        }
    }
}