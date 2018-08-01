module ppl2.gen.gen_binary;

import ppl2.internal;

final class BinaryGenerator {
    ModuleGenerator gen;
    LLVMBuilder builder;

    this(ModuleGenerator gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(Binary b) {
        Type type = b.type;

        //dd("binary", b, "left=", b.left.id, "right=", b.right.id);
        //dd("  left");
        b.left.visit!ModuleGenerator(gen);
        auto left	   = gen.rhs;
        auto assignVar = gen.lhs;
        //dd("  assignvar=", assignVar.toString);

        //logln("left=%s", left);
        //logln("assignVar type is %s", assignVar.getType());

        if(b.op is Operator.BOOL_OR || b.op is Operator.BOOL_AND) {
            handleBooleanAndOrRightSide(b, left);
            return;
        }

        //dd("  right");
        b.right.visit!ModuleGenerator(gen);
        auto right = gen.rhs; //castType(rhs, b.rightType, type);
        //logln("right=%s", right);

        if(b.op.isBool) {
            //dd(0.1, b.op, b.leftType, b.rightType);
            Type cmpType = getBestFit(b.leftType, b.rightType);
            //dd(0.2, cmpType);
            //logln("\tcmpType is %s", cmpType);
            left  = gen.castType(left, b.leftType, cmpType);
            right = gen.castType(right, b.rightType, cmpType);

            if(b.op is Operator.BOOL_EQ) {
                eq(cmpType, left, right);
            } else if(b.op is Operator.COMPARE) {   /// BOOL_NE
                neq(cmpType, left, right);
            } else if(b.op is Operator.LT) {
                lt(cmpType, left, right);
            } else if(b.op is Operator.GT) {
                gt(cmpType, left, right);
            } else if(b.op is Operator.LTE) {
                lt_eq(cmpType, left, right);
            } else if(b.op is Operator.GTE) {
                gt_eq(cmpType, left, right);
            }
            gen.rhs = gen.castI1ToI8(gen.rhs);
        } else {

            //logln("type is %s", type);
            left  = gen.castType(left, b.leftType, type);
            right = gen.castType(right, b.rightType, type);
            //if(left)
            //	logln("left is %s", left.getType().toString());
            //if(right)
            //	logln("right is %s", right.getType().toString());

            if(b.op.id==Operator.ADD.id || b.op is Operator.ADD_ASSIGN) {
                right = add(type, left, right);
            } else if(b.op is Operator.SUB || b.op is Operator.SUB_ASSIGN) {
                right = sub(type, left, right);
            } else if(b.op is Operator.MUL || b.op is Operator.MUL_ASSIGN) {
                right = mul(type, left, right);
            } else if(b.op is Operator.DIV || b.op is Operator.DIV_ASSIGN) {
                right = div(type, left, right);
            } else if(b.op is Operator.MOD || b.op is Operator.MOD_ASSIGN) {
                right = mod(type, left, right);
            } else if(b.op is Operator.SHL || b.op is Operator.SHL_ASSIGN) {
                right = shl(left, right);
            } else if(b.op is Operator.SHR || b.op is Operator.SHR_ASSIGN) {
                right = shr(left, right);
            } else if(b.op is Operator.USHR || b.op is Operator.USHR_ASSIGN) {
                right = ushr(left, right);
            } else if(b.op is Operator.BIT_AND || b.op is Operator.BIT_AND_ASSIGN) {
                right = and(left, right);
            } else if(b.op is Operator.BIT_OR || b.op is Operator.BIT_OR_ASSIGN) {
                right = or(left, right);
            } else if(b.op is Operator.BIT_XOR || b.op is Operator.BIT_XOR_ASSIGN) {
                right = xor(left, right);
            }

            if(b.op.isAssign) {
                assign(right, assignVar);
            }
        }
    }
    //==========================================================================================
private:
    ///
	/// Handle the right hand side of a boolean and/or BinaryExpression.
	/// In certain cases, the result of the left hand side means we don't
	/// need to evaluate the right hand side at all.
	///
    void handleBooleanAndOrRightSide(Binary b, LLVMValueRef leftVar) {
        //auto rightLabel		 = gen.currentFunction.llvmValue.appendBasicBlock("right");
        //auto afterRightLabel = gen.currentFunction.llvmValue.appendBasicBlock("after_right");
        auto rightLabel		 = gen.createBlock(b, "right");
        auto afterRightLabel = gen.createBlock(b, "after_right");

        bool isOr            = b.op is Operator.BOOL_OR;

        // ensure lhs is a bool(i8)
        leftVar = gen.castType(leftVar, b.leftType, TYPE_BOOL);

        // create a temporary result
        auto resultVal = builder.alloca(i8Type(), "bool_result");
        builder.store(leftVar, resultVal);

        // do we need to evaluate the right side?
        LLVMValueRef cmpResult;
        if(isOr) {
            cmpResult = builder.icmp(LLVMIntPredicate.LLVMIntNE,
            leftVar, constI8(FALSE));
        } else {
            cmpResult = builder.icmp(LLVMIntPredicate.LLVMIntEQ,
            leftVar, constI8(FALSE));
        }
        builder.condBr(cmpResult, afterRightLabel, rightLabel);

        // evaluate right side
        builder.positionAtEndOf(rightLabel);
        b.right.visit!ModuleGenerator(gen);
        gen.rhs = gen.castType(gen.rhs, b.rightType, TYPE_BOOL);
        builder.store(gen.rhs, resultVal);
        builder.br(afterRightLabel);

        // after right side
        builder.positionAtEndOf(afterRightLabel);
        gen.rhs = builder.load(resultVal);
    }
    void eq(Type cmpType, LLVMValueRef left, LLVMValueRef right) {
        if(cmpType.isReal)
            gen.rhs = builder.fcmp(LLVMRealPredicate.LLVMRealOEQ, left, right);
        else
            gen.rhs = builder.icmp(LLVMIntPredicate.LLVMIntEQ, left, right);
    }
    void neq(Type cmpType, LLVMValueRef left, LLVMValueRef right) {
        if(cmpType.isReal)
            gen.rhs = builder.fcmp(LLVMRealPredicate.LLVMRealONE, left, right);
        else
            gen.rhs = builder.icmp(LLVMIntPredicate.LLVMIntNE, left, right);
    }
    void lt(Type cmpType, LLVMValueRef left, LLVMValueRef right) {
        if(cmpType.isReal)
            gen.rhs = builder.fcmp(LLVMRealPredicate.LLVMRealOLT, left, right);
        else {
            gen.rhs = builder.icmp(LLVMIntPredicate.LLVMIntSLT, left, right);
        }
    }
    void gt(Type cmpType, LLVMValueRef left, LLVMValueRef right) {
        if(cmpType.isReal)
            gen.rhs = builder.fcmp(LLVMRealPredicate.LLVMRealOGT, left, right);
        else {
            gen.rhs = builder.icmp(LLVMIntPredicate.LLVMIntSGT, left, right);
        }
    }
    void lt_eq(Type cmpType, LLVMValueRef left, LLVMValueRef right) {
        if(cmpType.isReal)
            gen.rhs = builder.fcmp(LLVMRealPredicate.LLVMRealOLE, left, right);
        else {
            gen.rhs = builder.icmp(LLVMIntPredicate.LLVMIntSLE, left, right);
        }
    }
    void gt_eq(Type cmpType, LLVMValueRef left, LLVMValueRef right) {
        if(cmpType.isReal)
            gen.rhs = builder.fcmp(LLVMRealPredicate.LLVMRealOGE, left, right);
        else {
            gen.rhs = builder.icmp(LLVMIntPredicate.LLVMIntSGE, left, right);
        }
    }
    void assign(LLVMValueRef right, LLVMValueRef assignVar) {
        //dd("    Assign");
        //dd("       ", right.toString, "(", right.getType.toString, ")");
        //dd("    to");
        //dd("       ", assignVar.toString, "(", assignVar.getType.toString, ")");
        builder.store(right, assignVar);
    }
    auto add(Type type, LLVMValueRef left, LLVMValueRef right) {
        auto op = type.isReal ? LLVMOpcode.LLVMFAdd : LLVMOpcode.LLVMAdd;
        gen.rhs = builder.binop(op, left, right);
        return gen.rhs;
    }
    auto sub(Type type, LLVMValueRef left, LLVMValueRef right) {
        auto op = type.isReal ? LLVMOpcode.LLVMFSub : LLVMOpcode.LLVMSub;
        gen.rhs = builder.binop(op, left, right);
        return gen.rhs;
    }
    auto mul(Type type, LLVMValueRef left, LLVMValueRef right) {
        auto op = type.isReal ? LLVMOpcode.LLVMFMul : LLVMOpcode.LLVMMul;
        gen.rhs = builder.binop(op, left, right);
        return gen.rhs;
    }
    auto div(Type type, LLVMValueRef left, LLVMValueRef right) {
        auto op = type.isReal ? LLVMOpcode.LLVMFDiv : LLVMOpcode.LLVMSDiv;
        gen.rhs = builder.binop(op, left, right);
        return gen.rhs;
    }
    auto mod(Type type, LLVMValueRef left, LLVMValueRef right) {
        auto op = type.isReal ? LLVMOpcode.LLVMFRem : LLVMOpcode.LLVMSRem;
        gen.rhs = builder.binop(op, left, right);
        return gen.rhs;
    }
    auto shl(LLVMValueRef left, LLVMValueRef right) {
        gen.rhs = builder.binop(LLVMOpcode.LLVMShl, left, right);
        return gen.rhs;
    }
    auto shr(LLVMValueRef left, LLVMValueRef right) {
        gen.rhs = builder.binop(LLVMOpcode.LLVMAShr, left, right);
        return gen.rhs;
    }
    auto ushr(LLVMValueRef left, LLVMValueRef right) {
        gen.rhs = builder.binop(LLVMOpcode.LLVMLShr, left, right);
        return gen.rhs;
    }
    auto and(LLVMValueRef left, LLVMValueRef right) {
        gen.rhs = builder.binop(LLVMOpcode.LLVMAnd, left, right);
        return gen.rhs;
    }
    auto or(LLVMValueRef left, LLVMValueRef right) {
        gen.rhs = builder.binop(LLVMOpcode.LLVMOr, left, right);
        return gen.rhs;
    }
    auto xor(LLVMValueRef left, LLVMValueRef right) {
        gen.rhs = builder.binop(LLVMOpcode.LLVMXor, left, right);
        return gen.rhs;
    }
}