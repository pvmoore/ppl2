module ppl2.gen.gen_struct;

import ppl2.internal;

void generateImportedStructDeclarations(Module module_) {
    foreach(s; module_.getImportedNamedStructs()) {
        setTypes(s.getLLVMType(), s.type.getLLVMTypes(), true);
    }
}
void generateLocalStructDeclarations(Module module_) {
    foreach(s; module_.getNamedStructsRecurse()) {
        setTypes(s.getLLVMType(), s.type.getLLVMTypes(), true);
    }
}