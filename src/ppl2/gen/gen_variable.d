module ppl2.gen.gen_variable;

import ppl2.internal;

void generateLocalGlobalVariables(Module module_) {
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
void generateImportedGlobalDeclarations(Module module_) {
    foreach(v; module_.getImportedStaticVariables()) {
        auto g = module_.llvmValue.addGlobal(v.type.getLLVMType(), v.name);
        g.setInitialiser(undef(v.type.getLLVMType()));
        g.setLinkage(LLVMLinkage.LLVMAvailableExternallyLinkage);
        v.llvmValue = g;
    }
}