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

    //// inline
    //bool isInline   = f.isOperatorOverload;
    //bool isNoInline = false;

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

    addFunctionAttribute(func, LLVMAttribute.NoUnwind);

    //// linkage
    //if(!f.isExport && f.access==Access.PRIVATE) {
    //    f.llvmValue.setLinkage(LLVMLinkage.LLVMInternalLinkage);
    //}
}
/*
void generateFunctionBody(Node f, Type type, LLVMValueRef llvmValue) {

    auto numArgs = type.func.argTypes.length;

    if(llvmValue is null) error("!!! func %s llvmValue is null".format(f));
    auto args  = getFunctionArgs(llvmValue);
    auto entry = llvmValue.appendBasicBlock("entry");
    builder.positionAtEndOf(entry);

    // set the arg values into local variable allocs
    // so that we can store to them later if needed
    foreach(i, n; f.children[0..numArgs]) {
        n.visit!Generator(gen);
        builder.store(args[i], gen.lhs);
    }

    // visit the body nodes
    foreach(Node n; f.children[numArgs..$]) {
        n.visit!Generator(gen);
    }

    if(type.func.returnType.isVoid) {
        if(!f.hasChild || !f.lastChild.isReturn) {
            builder.retVoid();
        }
    }
}
*/