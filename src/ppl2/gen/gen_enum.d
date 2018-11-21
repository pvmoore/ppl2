module ppl2.gen.gen_enum;

import ppl2.internal;

void generateLocalEnumDeclarations(Module module_) {
    foreach(e; module_.getEnumsRecurse()) {
        setTypes(e.getLLVMType(), [e.elementType.getLLVMType], true);
    }
}
void generateImportedEnumDeclarations(Module module_) {
    foreach(e; module_.getImportedEnums()) {
        setTypes(e.getLLVMType(), [e.elementType.getLLVMType], true);
    }
}
