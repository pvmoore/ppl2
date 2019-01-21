module ppl2.gen.gen_select;

import ppl2.internal;

final class SelectGenerator {
    ModuleGenerator gen;
    LLVMBuilder builder;

    this(ModuleGenerator gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(Select n) {
        auto startLabel = gen.createBlock(n, "select");
        LLVMBasicBlockRef[] blocks;
        LLVMValueRef[]      phiValues;
        LLVMBasicBlockRef[] phiBlocks;

        auto cases = n.cases();
        auto def   = n.defaultStmts();

        foreach(i; 0..cases.length) {
            blocks ~= gen.createBlock(n, "select_block_"~i.to!string);
        }

        auto elseLabel  = gen.createBlock(n, "select_else");
        auto endLabel   = gen.createBlock(n, "select_end");

        builder.br(startLabel);

        /// Select
        gen.moveToBlock(startLabel);

        /// inits
        if(n.hasInitExpr) {
            n.initExprs().visit!ModuleGenerator(gen);
        }

        /// Value
        n.valueExpr().visit!ModuleGenerator(gen);

        auto switch_ = builder.switch_(gen.rhs, elseLabel, cases.length.toInt);

        /// Case conditions
        foreach(i, c; cases) {

            foreach(expr; c.conds()) {
                expr.visit!ModuleGenerator(gen);
                gen.castType(gen.rhs, c.cond().getType, n.valueType);

                switch_.addCase(gen.rhs, blocks[i]);
            }

            //c.cond().visit!ModuleGenerator(gen);
            //gen.castType(gen.rhs, c.cond().getType, n.valueType);
            //
            //switch_.addCase(gen.rhs, blocks[i]);
        }
        /// Case blocks
        foreach(i, c; cases) {
            gen.moveToBlock(blocks[i]);

            c.stmts().visit!ModuleGenerator(gen);

            if(n.isExpr) {
                gen.castType(gen.rhs, c.stmts().getType, n.type);

                phiValues ~= gen.rhs;
                phiBlocks ~= gen.currentBlock;
            }

            if(!c.stmts().endsWithReturn) {
                builder.br(endLabel);
            }
        }
        /// else
        gen.moveToBlock(elseLabel);
        def.visit!ModuleGenerator(gen);

        if(n.isExpr) {
            gen.castType(gen.rhs, def.getType, n.type);

            phiValues ~= gen.rhs;
            phiBlocks ~= gen.currentBlock;
        }

        if(!def.endsWithReturn) {
            builder.br(endLabel);
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