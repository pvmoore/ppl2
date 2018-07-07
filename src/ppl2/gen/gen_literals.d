module ppl2.gen.gen_literals;

import ppl2.internal;

final class LiteralGenerator {
    ModuleGenerator gen;
    LLVMBuilder builder;

    this(ModuleGenerator gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(LiteralArray n) {

        /// Alloca some space
        string name = n.generateName();
        gen.lhs  = builder.alloca(n.type.getLLVMType(), name);
        auto ptr = gen.lhs;

        if(n.isIndexBased) {
            /// Set to all zeroes
            builder.store(constAllZeroes(n.type.getLLVMType()), ptr);

            auto indices = n.elementIndexes();
            auto values  = n.elementValues();
            assert(indices.length==values.length);

            foreach(i, idx; indices) {
                auto index = idx.as!LiteralNumber.value.getInt();
                auto ele   = values[i];

                ele.visit!ModuleGenerator(gen);
                gen.rhs = gen.castType(gen.rhs, ele.getType, n.type.subtype);

                gen.setArrayValue(ptr, gen.rhs, index, "[%s]".format(index));
            }
        } else {

            /// Set the values
            foreach(int i, ch; n.elementValues()) {
                ch.visit!ModuleGenerator(gen);
                gen.rhs = gen.castType(gen.rhs, ch.getType, n.type.subtype);

                gen.setArrayValue(ptr, gen.rhs, i, "[%s]".format(i));
            }
        }
        gen.rhs = builder.load(gen.lhs);
    }
    void generate(LiteralFunction n) {
        if(n.isClosure) {
            /// Generate declaration

            assert(false, "implement me");
        }
        auto func       = n.getFunction();
        auto type       = n.type.getFunctionType;
        auto paramTypes = type.paramTypes();
        auto numParams  = paramTypes.length;
        assert(func.llvmValue, "Function value is null: %s".format(func));

        //auto args  = getFunctionArgs(func.llvmValue);
        auto entry = func.llvmValue.appendBasicBlock("entry");
        builder.positionAtEndOf(entry);

        /// Visit body statements
        foreach(ch; n.children) {
            ch.visit!ModuleGenerator(gen);
        }

        if(type.returnType().isVoid) {
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