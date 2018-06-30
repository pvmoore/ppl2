module ppl2.gen.gen_variable;

import ppl2.internal;


void generateGlobalVariables(Module module_) {
    foreach(v; module_.getVariables()) {
        auto g = module_.llvmValue.addGlobal(v.type.getLLVMType(), v.name);
        //g.setInitialiser(v.type.zero);
        g.setLinkage(LLVMLinkage.LLVMInternalLinkage);
        v.llvmValue = g;
    }
}
/*
void generate(Variable v) {
    // global vars already generated in generateGlobals() function
    if(v.isGlobalVar) return;
    // struct vars are generated in gen_struct
    if(v.isStructVar) return;

    // it must be a local var

    logln("Generating local ... %s", v);
    gen.lhs = builder.alloca(v.type.toLLVMType, v.name);
    v.llvmValue = gen.lhs;

    if(v.hasInitialiser) {
        v.initialiser.visit!Generator(gen);
        //gen.rhs = gen.castType(left, b.leftType, cmpType);

        logln("assign: %s to %s", v.initialiser.getType.toString, v.type.toString);
        builder.store(gen.rhs, v.llvmValue);
    }
    logln("\tend of generating variable");
}
*/