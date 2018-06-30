module ppl2.gen.gen_struct;

import ppl2.internal;

void generateStructDeclarations(Module module_) {
    foreach(s; module_.getNamedStructs()) {
        setTypes(s.getLLVMType(), s.type.getLLVMTypes(), true);
    }
    foreach(s; module_.getImportedNamedStructs()) {
        setTypes(s.getLLVMType(), s.type.getLLVMTypes(), true);
    }
}