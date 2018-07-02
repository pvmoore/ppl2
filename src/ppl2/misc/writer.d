module ppl2.misc.writer;

import ppl2.internal;

void writeLL(Module m, string subdir) {
    string path = getConfig().targetPath ~ subdir;
    m.llvmValue.writeToFileLL(path ~ m.canonicalName ~ ".ll");
}
bool writeASM(LLVMWrapper llvm, Module m) {
    if(getConfig().writeASM) {
        string path = getConfig().targetPath ~ m.canonicalName ~ ".asm";
        if(!llvm.x86Target.writeToFileASM(m.llvmValue, path)) {
            log("failed to write ASM %s", path);
            return false;
        }
    }
    return true;
}
bool writeOBJ(LLVMWrapper llvm, Module m) {
    string path = getConfig().targetPath ~ m.canonicalName ~ ".obj";
    if(!llvm.x86Target.writeToFileOBJ(m.llvmValue, path)) {
        log("failed to write OBJ %s", path);
        return false;
    }
    return true;
}
