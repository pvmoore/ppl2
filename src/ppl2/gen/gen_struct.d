module ppl2.gen.gen_struct;

import ppl2.internal;

void generateImportedStructDeclarations(Module module_) {
    foreach(s; module_.getImportedStructs()) {
        setTypes(s.getLLVMType(), s.getLLVMTypes(), true);
    }
}
void generateLocalStructDeclarations(Module module_) {
    foreach(s; module_.getStructsRecurse()) {
        setTypes(s.getLLVMType(), s.getLLVMTypes(), true);
    }
}