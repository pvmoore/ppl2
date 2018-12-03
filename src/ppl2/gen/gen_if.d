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
        auto ifLabel   = gen.createBlock(n, "if");
        auto thenLabel = gen.createBlock(n, "then");
        auto elseLabel = n.hasElse ? gen.createBlock(n, "else") : null;
        auto endLabel  = gen.createBlock(n, "endif");

        LLVMValueRef[]      phiValues;
        LLVMBasicBlockRef[] phiBlocks;

        builder.br(ifLabel);

        /// If
        gen.moveToBlock(ifLabel);

        /// inits
        if(n.hasInitExpr) {
            n.initExprs().visit!ModuleGenerator(gen);
        }

        /// condition
        n.condition.visit!ModuleGenerator(gen);

        auto cmp = builder.icmp(LLVMIntPredicate.LLVMIntNE, gen.rhs, n.condition.getType.zeroValue);

        auto expect = n.attributes.get!ExpectAttribute;
        if(expect) {
            auto expectValue = expect.value ? constI1(1) : constI1(0);
            cmp = gen.expectI1(cmp, expectValue);
        }

        builder.condBr(cmp, thenLabel, n.hasElse ? elseLabel : endLabel);

        /// then
        gen.moveToBlock(thenLabel);

        n.thenStmt().visit!ModuleGenerator(gen);

        if(n.isExpr) {
            gen.castType(gen.rhs, n.thenType(), n.type);

            phiValues ~= gen.rhs;
            phiBlocks ~= gen.currentBlock;
        }

        if(!n.thenBlockEndsWithReturn) {
            builder.br(endLabel);
        }

        /// else
        if(n.hasElse) {
            gen.moveToBlock(elseLabel);

            n.elseStmt().visit!ModuleGenerator(gen);

            if(n.isExpr) {
                gen.castType(gen.rhs, n.elseType(), n.type);

                phiValues ~= gen.rhs;
                phiBlocks ~= gen.currentBlock;
            }

            if(!n.elseBlockEndsWithReturn) {
                builder.br(endLabel);
            }
        }

        /// end
        gen.moveToBlock(endLabel);
        if(n.isExpr) {
            auto phi = builder.phi(n.type.getLLVMType);
            phi.addIncoming(phiValues, phiBlocks);

            gen.rhs = phi;
        }
    }
}