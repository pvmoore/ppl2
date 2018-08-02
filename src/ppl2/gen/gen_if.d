module ppl2.gen.gen_if;

import ppl2.internal;

final class IfGenerator {
    ModuleGenerator gen;
    LLVMBuilder builder;

    this(ModuleGenerator gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(If n) {
        auto thenLabel = gen.createBlock(n, "then");
        auto elseLabel = n.hasElse ? gen.createBlock(n, "else") : null;
        auto endLabel  = gen.createBlock(n, "endif");

        LLVMValueRef result;
        if(n.isExpr) {
            result = builder.alloca(n.type.getLLVMType, "if_result");
        }

        /// inits
        if(n.hasInitExpr) {
            n.initExprs().visit!ModuleGenerator(gen);
        }

        /// condition
        n.condition.visit!ModuleGenerator(gen);

        auto cmp = builder.icmp(LLVMIntPredicate.LLVMIntNE, gen.rhs, n.condition.getType.zero);

        //if(i.attributes && i.attributes.has(AttrType.EXPECT)) {
        //    auto expect = i.attributes.get(AttrType.EXPECT);
        //    cmp = gen.expect(cmp, expect.llvmValue);
        //}
        builder.condBr(cmp, thenLabel, n.hasElse ? elseLabel : endLabel);

        /// then
        builder.positionAtEndOf(thenLabel);
        //if(n.hasThen) {

            n.thenStmt().visit!ModuleGenerator(gen);

            if(n.isExpr) {
                gen.castType(gen.rhs, n.thenType(), n.type);
                builder.store(gen.rhs, result);
            }

            if(!n.thenBlockEndsWithReturn) {

                builder.br(endLabel);
            }
        //} else {
        //    builder.br(endLabel);
        //}

        /// else
        builder.positionAtEndOf(elseLabel);
        if(n.hasElse) {
            n.elseStmt().visit!ModuleGenerator(gen);

            if(n.isExpr) {
                gen.castType(gen.rhs, n.elseType(), n.type);
                builder.store(gen.rhs, result);
            }

            if(!n.elseBlockEndsWithReturn) {
                builder.br(endLabel);
            }
        }

        builder.positionAtEndOf(endLabel);
        if(n.isExpr) {
            gen.rhs = builder.load(result);
        }
    }
}