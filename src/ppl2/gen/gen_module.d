module ppl2.gen.gen_module;

import ppl2.internal;

final class ModuleGenerator {
public:
    Module module_;
    LLVMWrapper llvm;
    LLVMBuilder builder;
    LLVMValueRef lhs;
    LLVMValueRef rhs;

    LLVMValueRef memsetFunc;
    LLVMValueRef expectBoolFunc;
    //LLVMValueRef memcmpFunc;

    this(Module module_, LLVMWrapper llvm) {
        this.module_ = module_;
        this.llvm    = llvm;
        this.builder = llvm.builder;
    }
    void generate() {
        log("Generating IR for module %s", module_.canonicalName);

        this.lhs = null;
        this.rhs = null;

        module_.llvmValue = llvm.createModule(module_.canonicalName);


        generateGlobalStrings();
        generateIntrinsicFuncDeclarations();
        generateFunctionDeclarations(module_);
        generateStructDeclarations();

        visitChildren(module_);

        writeLL(module_);
    }
    //======================================================================================
    void visit(AnonStruct n) {

    }
    void visit(Function n) {

    }
    void visit(LiteralFunction n) {

    }
    void visit(NamedStruct n) {

    }
    void visit(Variable n) {

    }
private:
    void visitChildren(ASTNode n) {
        foreach(ch; n.children) {
            ch.visit!ModuleGenerator(this);
        }
    }
    void generateGlobalStrings() {
        foreach(LiteralString[] array; module_.literalStrings.values) {
            /// create a global string for only one of these
            auto s = array[0];
            log("Generating string literal decl ... %s", s);
            auto str = constString(s.value);
            auto g   = module_.llvmValue.addGlobal(str.getType);
            g.setInitialiser(str);
            g.setConstant(true);
            g.setLinkage(LLVMLinkage.LLVMInternalLinkage);

            auto llvmValue = builder.bitcast(g, pointerType(i8Type()));
            //// set the same llvmValue on each reference
            foreach(sl; array) {
                sl.llvmValue = llvmValue;
            }
        }
    }
    void generateIntrinsicFuncDeclarations() {
        memsetFunc = module_.llvmValue.addFunction(
            "llvm.memset.p0i8.i32",
            voidType(),
            [bytePointerType(), i8Type(), i32Type(), i32Type(), i1Type()],
            LLVMCallConv.LLVMCCallConv
        );
        expectBoolFunc = module_.llvmValue.addFunction(
            "llvm.expect.i1",
            i1Type(),
            [i1Type(), i1Type()],
            LLVMCallConv.LLVMCCallConv
        );
        //		memcmpFunc = llvmmod.addFunction(
        //            "memcmp",
        //            i32Type(),
        //            [bytePointerType(), bytePointerType(), i64Type()],
        //            LLVMCallConv.LLVMCCallConv
        //		);
    }

    void generateStructDeclarations() {
    //    // do this in 2 phases to allow embedded structs
    //    Struct[] structs = m.structs.allLocalConcrete;
    //
    //    foreach(Struct s; structs) {
    //        logln("Generating struct decl ... %s", s);
    //        s.llvmType = struct_(s.name);
    //    }
    //    foreach(s; m.imports.getImportedStructs) {
    //        logln("Generating imported struct decl ... %s", s);
    //        s.llvmType = struct_(s.name);
    //    }
    //    foreach(Struct s; structs) {
    //        logln("Adding struct body: %s", s.name);
    //        auto elementTypes = s.types.map!(it=>it.toLLVMType).array;
    //
    //        setTypes(s.llvmType, elementTypes, true);
    //    }
    //    foreach(s; m.imports.getImportedStructs) {
    //        logln("[%s] Adding imported struct body: %s",m.name, s.name);
    //        auto elementTypes = s.types.map!(it=>it.toLLVMType).array;
    //        setTypes(s.llvmType, elementTypes, true);
    //    }
    }
}