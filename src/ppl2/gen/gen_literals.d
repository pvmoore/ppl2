module ppl2.gen.gen_literals;

import ppl2.internal;

final class LiteralGenerator {
    ModuleGenerator gen;
    LLVMBuilder builder;

    this(ModuleGenerator gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(LiteralFunction n) {
        if(n.isClosure) {
            /// Generate declaration

            assert(false, "implement me");
        }
        auto func     = n.getFunction();
        auto argTypes = n.type.argTypes();
        auto numArgs  = argTypes.length;
        assert(func.llvmValue, "Function value is null: %s".format(func));

        auto args  = getFunctionArgs(func.llvmValue);
        auto entry = func.llvmValue.appendBasicBlock("entry");
        builder.positionAtEndOf(entry);

        /// Visit body statements
        foreach(ch; n.children) {
            ch.visit!ModuleGenerator(gen);
        }

        if(n.type.returnType().isVoid) {
            if(!n.hasChildren || !n.last().isReturn) {
                builder.retVoid();
            }
        }
    }
    void generate(LiteralNull n) {
        gen.rhs = constNullPointer(n.type.getLLVMType());
    }
    void generate(LiteralNumber n) {
        LLVMValueRef value;
        switch(n.type.getEnum) with(Type) {
            case BOOL:   value = constI8(n.value.getInt()); break;
            case BYTE:   value = constI8(n.value.getInt()); break;
            case SHORT:  value = constI16(n.value.getInt()); break;
            case INT:    value = constI32(n.value.getInt()); break;
            case LONG:   value = constI64(n.value.getLong()); break;
            case HALF:   value = constF16(n.value.getDouble()); break;
            case FLOAT:  value = constF32(n.value.getDouble()); break;
            case DOUBLE: value = constF64(n.value.getDouble()); break;
            default:
            assert(false, "Invalid type %s".format(n.type));
        }
        gen.rhs = value;
    }
    void generate(LiteralString n) {
        assert(n.llvmValue);
        gen.rhs = n.llvmValue;
    }
}