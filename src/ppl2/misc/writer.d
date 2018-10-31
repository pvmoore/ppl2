module ppl2.misc.writer;

import ppl2.internal;

void writeLL(Module m, string subdir) {
    if(m.config.writeIR) {
        string path = m.config.targetPath ~ subdir;
        m.llvmValue.writeToFileLL(path ~ m.fileName ~ ".ll");
    }
}
bool writeASM(LLVMWrapper llvm, Module m) {
    if(m.config.writeASM) {
        string path = m.config.targetPath ~ m.fileName ~ ".asm";
        if(!llvm.x86Target.writeToFileASM(m.llvmValue, path)) {
            log("failed to write ASM %s", path);
            return false;
        }
    }
    return true;
}
bool writeOBJ(LLVMWrapper llvm, Module m) {
    string path = m.config.targetPath ~ m.fileName ~ ".obj";
    if(!llvm.x86Target.writeToFileOBJ(m.llvmValue, path)) {
        log("failed to write OBJ %s", path);
        return false;
    }
    return true;
}
