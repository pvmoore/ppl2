module ppl2.gen.gen_function;

import ppl2.internal;

void generateFunctionDeclarations(Module module_) {
    foreach(f; module_.getLocalFunctions) {
        generateFunctionDeclaration(module_, f);
    }
    foreach(f; module_.getImportedFunctions) {
        generateFunctionDeclaration(module_, f);
    }
}
void generateFunctionDeclaration(Module module_, Function f) {
    log("Generating func decl ... %s", f.getUniqueName);
    auto type = f.getType.getFunctionType;
    auto func = module_.llvmValue.addFunction(
        f.getUniqueName(),
        type.returnType.getLLVMType(),
        type.argTypes.map!(it=>it.getLLVMType()).array,
        f.getCallingConvention()
    );
    f.llvmValue = func;
    //
    //// inline
    //bool isInline   = f.isOperatorOverload;
    //bool isNoInline = false;
    //
    //// check if user has set a preference
    //if(f.attributes && f.attributes.has(AttrType.INLINE)) {
    //    auto inline = f.attributes.get(AttrType.INLINE);
    //    isInline   = "-1"==inline.value;
    //    isNoInline = !isInline;
    //}
    //if(isInline) {
    //    addFunctionAttribute(func, LLVMAttribute.AlwaysInline);
    //} else if(isNoInline) {
    //    addFunctionAttribute(func, LLVMAttribute.NoInline);
    //}
    //
    //addFunctionAttribute(func, LLVMAttribute.NoUnwind);
    //
    //// linkage
    //if(!f.isExported && f.access.isPrivate) {
    //    f.llvmValue.setLinkage(LLVMLinkage.LLVMInternalLinkage);
    //}
}