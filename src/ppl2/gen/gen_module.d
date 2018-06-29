module ppl2.gen.gen_module;

import ppl2.internal;

final class ModuleGenerator {
public:
    Module module_;
    LLVMWrapper llvm;
    LLVMValueRef lhs;
    LLVMValueRef rhs;

    this(Module module_, LLVMWrapper llvm) {
        this.module_ = module_;
        this.llvm    = llvm;
    }
    void generate() {
        log("Generating IR for module %s", module_.canonicalName);

        /// Generate:
        ///     - literal strings
        ///     - literal functions

        this.lhs        = null;
        this.rhs        = null;

        module_.llvmValue = llvm.createModule(module_.canonicalName);

        visitChildren(module_);

        writeLL(module_);
    }
    //======================================================================================
    void visit(AnonStruct n) {

    }
    void visit(Define n) {
        // todo - should we have removed this earlier?
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
}