module ppl2.gen.gen_function;

import ppl2.internal;

void generateStandardFunctionDeclarations(Module module_) {
    foreach(f; module_.getFunctions()) {
        generateFunctionDeclaration(module_, f);
    }
}
void generateImportedFunctionDeclarations(Module module_) {
    foreach(f; module_.getImportedFunctions) {
        generateFunctionDeclaration(module_, f);
    }
}

void generateLocalStructFunctionDeclarations(Module module_) {
    foreach(ns; module_.getStructsRecurse()) {
        foreach(f; ns.getMemberFunctions()) {
            generateFunctionDeclaration(module_, f);
        }
        foreach(f; ns.getStaticFunctions()) {
            generateFunctionDeclaration(module_, f);
        }
    }
}

void generateInnerFunctionDeclarations(Module module_) {
    foreach(f; module_.getInnerFunctions()) {
        generateFunctionDeclaration(module_, f);
    }
}
void generateInnerFunctionBodies(Module module_, LiteralGenerator literalGen) {
    foreach(f; module_.getInnerFunctions()) {
        auto litFunc = f.getBody();
        literalGen.generate(litFunc, f.llvmValue);
    }
}
void generateLocalStructMemberFunctionBodies(Module module_, LiteralGenerator literalGen) {
    foreach(ns; module_.getStructsRecurse()) {
        foreach(f; ns.getMemberFunctions()) {
            auto litFunc = f.getBody();
            literalGen.generate(litFunc, f.llvmValue);
        }
        foreach(f; ns.getStaticFunctions()) {
            auto litFunc = f.getBody();
            literalGen.generate(litFunc, f.llvmValue);
        }
    }
}
void generateClosureDeclarations(Module module_) {
    foreach(c; module_.getClosures()) {
        generateClosureDeclaration(module_, c);
    }
}
void generateClosureBodies(Module module_, LiteralGenerator literalGen) {
    foreach(c; module_.getClosures()) {
        auto litFunc = c.getBody();
        literalGen.generate(litFunc, c.llvmValue);
    }
}
void generateClosureDeclaration(Module m, Closure c) {
    auto litFunc = c.getBody();
    auto type    = litFunc.type.getFunctionType;

    auto func = m.llvmValue.addFunction(
        c.name,
        type.returnType.getLLVMType,
        type.paramTypes.map!(it=>it.getLLVMType).array,
        LLVMCallConv.LLVMFastCallConv
    );
    c.llvmValue = func;

    if(m.config.enableInlining) {
        addFunctionAttribute(func, LLVMAttribute.InlineHint);
    }
    addFunctionAttribute(func, LLVMAttribute.NoUnwind);

    func.setLinkage(LLVMLinkage.LLVMInternalLinkage);
}
private:
void generateFunctionDeclaration(Module module_, Function f) {
    auto type = f.getType.getFunctionType;
    auto func = module_.llvmValue.addFunction(
        f.getMangledName(),
        type.returnType.getLLVMType(),
        type.paramTypes().map!(it=>it.getLLVMType()).array,
        f.getCallingConvention()
    );
    f.llvmValue = func;

    auto config = module_.config;

    //// inline
    bool isInline   = false;
    bool isNoInline = false;

    if(!config.enableInlining) {
        isInline = false;
    }

    /// Check if the user has set an attribute
    auto attr = f.attributes.get!InlineAttribute;
    if(attr) {
        isInline   = attr.value;
        isNoInline = !isInline;
    }

    if(isInline) {
        addFunctionAttribute(func, LLVMAttribute.AlwaysInline);
    } else if(isNoInline) {
        addFunctionAttribute(func, LLVMAttribute.NoInline);
    }

    /// We don't support exceptions
    addFunctionAttribute(func, LLVMAttribute.NoUnwind);

    //// linkage
    //if(!f.isExport && f.access==Access.PRIVATE) {
    if(f.numExternalRefs==0 && !f.isProgramEntry && !config.disableInternalLinkage) {
        f.llvmValue.setLinkage(LLVMLinkage.LLVMInternalLinkage);
    }

    //if(module_.canonicalName=="test_imports" && f.name=="new") {
    //    dd("!! linkage", f.getUniqueName, f.numExternalRefs, isInline, f.llvmValue.getLinkage);
    //}
}
