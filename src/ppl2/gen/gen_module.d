module ppl2.gen.gen_module;

import ppl2.internal;

final class ModuleGenerator {
public:
    Module module_;
    BinaryGenerator binaryGen;
    LiteralGenerator literalGen;

    LLVMWrapper llvm;
    LLVMBuilder builder;
    LLVMValueRef lhs;
    LLVMValueRef rhs;

    LLVMValueRef memsetFunc;
    LLVMValueRef expectBoolFunc;
    //LLVMValueRef memcmpFunc;

    LLVMValueRef[string] structMemberThis;  /// key = struct.getUniqueName

    this(Module module_, LLVMWrapper llvm) {
        this.module_    = module_;
        this.llvm       = llvm;
        this.builder    = llvm.builder;
        this.binaryGen  = new BinaryGenerator(this);
        this.literalGen = new LiteralGenerator(this);
    }
    bool generate() {
        log("Generating IR for module %s", module_.canonicalName);

        this.lhs = null;
        this.rhs = null;

        module_.llvmValue = llvm.createModule(module_.canonicalName);

        generateGlobalStrings();
        generateGlobalVariables();
        generateImportedStructDeclarations(module_);

        generateIntrinsicFuncDeclarations();
        generateStandardFunctionDeclarations(module_);
        generateStructMemberFunctionDeclarations(module_);
        generateImportedFunctionDeclarations(module_);

        visitChildren(module_);

        writeLL(module_, "ir/");

        return verify();
    }
    //======================================================================================
    void visit(AddressOf n) {
        dd("visit AddressOf");
        n.expr().visit!ModuleGenerator(this);

        rhs = lhs;
    }
    void visit(AnonStruct n) {
        dd("visit AnonStruct");

        foreach(f; n.getMemberFunctions()) {
            f.visit!ModuleGenerator(this);
        }
    }
    void visit(Arguments n) {
        dd("visit Arguments");
        auto func = n.getFunction();
        auto args = getFunctionArgs(func.llvmValue);

        foreach(i, v; n.getArgs()) {
            v.visit!ModuleGenerator(this);
            builder.store(args[i], lhs);

            /// Remember values of "this" so that we can access member variables later
            if(v.name=="this") {
                auto struct_ = v.type.getNamedStruct;
                assert(struct_);

                rhs = builder.load(lhs, "this");
                structMemberThis[struct_.getUniqueName] = args[i]; // rhs
            }
        }
    }
    void visit(As n) {
        dd("visit As");

        n.left.visit!ModuleGenerator(this);

        rhs = castType(rhs, n.left().getType, n.getType, "as");
    }
    void visit(Assert a) {
        dd("visit Assert");

        if(!getConfig().enableAsserts) {
            return;
        }

        log("Generating ... %s", a);

        auto thenLabel = createBlock(a, "assert_failed");
        auto endLabel  = createBlock(a, "assert_passed");

        a.expr().visit!ModuleGenerator(this);

        auto cmp = builder.icmp(LLVMIntPredicate.LLVMIntEQ, rhs, a.expr().getType.zero);
        builder.condBr(cmp, thenLabel, endLabel);

        /// assert failed
        builder.positionAtEndOf(thenLabel);

        LLVMValueRef[] argValues = [
            module_.moduleNameLiteral.llvmValue,
            constI32(a.line)
        ];
        // todo
        //builder.call(a.func.llvmValue, argValues, LLVMCallConv.LLVMFastCallConv);
        builder.unreachable();

        /// end
        builder.positionAtEndOf(endLabel);
    }
    void visit(Binary n) {
        dd("visit Binary", n.op);
        binaryGen.generate(n);
    }
    void visit(Call n) {
        dd("visit Call");
        Type returnType     = n.target.returnType;
        Type[] funcArgTypes	= n.target.argTypes;
        LLVMValueRef[] argValues;

        foreach(i, e; n.children[]) {
            e.visit!ModuleGenerator(this);
            argValues ~= castType(rhs, e.getType, funcArgTypes[i]);
        }

        if(n.target.isMemberVariable) {

            /// Get the "this" variable
            if(n.target.getVariable.isNamedStructMember) {
                auto struct_ = n.target.getVariable.getNamedStruct;
                assert(struct_);

                lhs = structMemberThis[struct_.getUniqueName];
            }

            int index = n.target.structMemberIndex;
            lhs = builder.getElementPointer_struct(lhs, index);
            rhs = builder.load(lhs, "rvalue");
            rhs = builder.call(rhs, argValues, LLVMCallConv.LLVMFastCallConv);
        } else if(n.target.isMemberFunction) {
            assert(n.target.llvmValue);
            rhs = builder.call(n.target.llvmValue, argValues, LLVMCallConv.LLVMFastCallConv);
        } else if(n.target.isVariable) {
            rhs = builder.load(n.target.llvmValue);
            rhs = builder.call(rhs, argValues, LLVMCallConv.LLVMFastCallConv);
        } else if(n.target.isFunction) {
            assert(n.target.llvmValue, "Function llvmValue is null: %s".format(n.target.getFunction));
            rhs = builder.call(n.target.llvmValue, argValues, n.target.getFunction().getCallingConvention());
        }
        //
        //if(returnType.isStruct &&
        //(c.parent.isDot || c.parent.isParens) &&
        //!returnType.isPointer)
        //{
        //    // special case for this no-op
        //    // we need to store the result locally
        //    // so that we can take a pointer to it
        //    gen.lhs = builder.alloca(returnType.toLLVMType, "returnValStorage");
        //    builder.store(gen.rhs, gen.lhs);
        //}
    }
    void visit(Constructor n) {
        dd("visit Constructor");
        visitChildren(n);
    }
    void visit(Dot n) {
        dd("visit Dot");
        n.left.visit!ModuleGenerator(this);

        if(n.left.getType.isPtr) {
            if(n.left.getType.getPtrDepth>1) {
                assert(false, "wasn't expecting this to happen!!!!");
            }
            /// automatically dereference the pointer
            lhs = rhs; //builder.load(gen.lhs);
        }

        n.right.visit!ModuleGenerator(this);
    }
    void visit(Function n) {
        dd("visit Function", n.name);
        if(!n.isExtern) {
            n.getBody().visit!ModuleGenerator(this);
        }
    }
    void visit(Identifier n) {
        dd("visit Identifier", n.name, n.target);
        if(n.target.isMemberFunction) {
            assert(false);
            //int index = n.target.structMemberIndex;
            //lhs = builder.getElementPointer_struct(lhs, index);
            //rhs = builder.load(lhs);
        } else if(n.target.isMemberVariable) {

            /// Get the "this" variable
            if(!n.parent.isDot && n.target.getVariable.isNamedStructMember) {
                auto struct_ = n.target.getVariable.getNamedStruct;
                assert(struct_);

                lhs = structMemberThis[struct_.getUniqueName];
            }

            int index = n.target.structMemberIndex;
            lhs = builder.getElementPointer_struct(lhs, index);
            rhs = builder.load(lhs);
        } else if(n.target.isFunction) {
            rhs = n.target.llvmValue;
        } else if(n.target.isVariable) {
            assert(n.target.llvmValue);
            lhs = n.target.llvmValue;
            rhs = builder.load(lhs);
        }
    }
    void visit(Index n) {
        dd("visit Index", n.getType);

        n.index().visit!ModuleGenerator(this);
        LLVMValueRef arrayIndex = rhs;

        n.left().visit!ModuleGenerator(this);

        if(n.isArrayIndex) {
            auto indices = [arrayIndex];
            lhs = builder.getElementPointer_inBounds(rhs, indices);
        } else if(n.isStructIndex) {

            // todo - handle "this"?

            lhs = builder.getElementPointer_struct(lhs, n.getIndexAsInt());
        } else if(n.isPtrIndex) {
            assert(false, "implement me");
        } else assert(false);

        //logln("index lhs is %s", lhs.getType.toString);
        rhs = builder.load(lhs);
        //logln("index rhs is %s", rhs.getType.toString);
    }
    void visit(Initialiser n) {
        dd("visit Initialiser");
        visitChildren(n);
    }
    void visit(LiteralArray n) {
        dd("visit LiteralArray");
        literalGen.generate(n);
    }
    void visit(LiteralFunction n) {
        dd("visit LiteralFunction");
        literalGen.generate(n);
    }
    void visit(LiteralNull n) {
        dd("visit LiteralNull");
        literalGen.generate(n);
    }
    void visit(LiteralNumber n) {
        dd("visit LiteralNumber", n);
        literalGen.generate(n);
    }
    void visit(Malloc n) {
        dd("visit Malloc");

        rhs = builder.malloc(n.valueType.getLLVMType(), "malloc");
    }
    void visit(LiteralString n) {
        dd("visit LiteralString");
        literalGen.generate(n);
    }
    void visit(NamedStruct n) {
        dd("visit NamedStruct", n.name);
        setTypes(n.getLLVMType(), n.type.getLLVMTypes(), true);

        visitChildren(n);
    }
    void visit(Parenthesis n) {
        n.expr().visit!ModuleGenerator(this);
    }
    void visit(Return n) {
        dd("visit Return");

        if(n.hasExpr) {
            n.expr().visit!ModuleGenerator(this);
            rhs = castType(rhs, n.expr().getType, n.getReturnType());
            builder.ret(rhs);
        } else {
            builder.retVoid();
        }
    }
    void visit(TypeExpr n) {
        /// ignore
    }
    void visit(ValueOf n) {
        n.expr().visit!ModuleGenerator(this);

        rhs = builder.load(rhs, "valueOf");
    }
    void visit(Variable n) {
        dd("visit Variable", n.name);
        if(n.isGlobal) {

        } else if(n.isStructMember) {

        } else {
            //// it must be a local/parameter

            lhs = builder.alloca(n.type.getLLVMType(), n.name);
            n.llvmValue = lhs;

            if(n.hasInitialiser) {
                n.initialiser.visit!ModuleGenerator(this);
                //gen.rhs = gen.castType(left, b.leftType, cmpType);

                //log("assign: %s to %s", n.initialiser.getType, n.type);
                //builder.store(rhs, n.llvmValue);
            } else if(!n.isParameter) {
                auto zero = constAllZeroes(n.type.getLLVMType());
                builder.store(zero, n.llvmValue);
            }
        }
    }
    //============================================================================================
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
    void generateGlobalVariables() {
        foreach(n; module_.getVariables()) {
            auto g = module_.llvmValue.addGlobal(n.type.getLLVMType(), n.name);
            g.setInitialiser(constAllZeroes(n.type.getLLVMType()));
            g.setLinkage(LLVMLinkage.LLVMInternalLinkage);
            n.llvmValue = g;
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
    void memsetZero(LLVMValueRef structPtr, int len) {
        auto i8Ptr = builder.bitcast(structPtr, bytePointerType());
        auto args = [
            i8Ptr, constI8(0), constI32(len), constI32(0),  constI1(0)
        ];
        builder.ccall(memsetFunc, args);
    }
    LLVMValueRef expect(LLVMValueRef value, LLVMValueRef expectedValue) {
        return builder.ccall(expectBoolFunc, [value, expectedValue]);
    }
    void setArrayValue(LLVMValueRef arrayPtr, LLVMValueRef value, uint index, string name=null) {
        auto indices = [constI32(0), constI32(index)];
        auto ptr = builder.getElementPointer_inBounds(arrayPtr, indices, name);
        builder.store(value, ptr);
    }
    void setStructValue(LLVMValueRef structPtr, LLVMValueRef value, uint paramIndex, string name=null) {
        //logln("setStructValue(%s = %s index:%s)",
        //	  structPtr.getType.toString, value.getType.toString, paramIndex);
        auto ptr = builder.getElementPointer_struct(structPtr, paramIndex, name);
        //logln("ptr is %s", ptr.getType.toString);
        builder.store(value, ptr);
    }
    LLVMBasicBlockRef createBlock(ASTNode n, string name) {
        auto body_ = n.getContainingFunctionBody();
        assert(body_);
        return body_.getFunction().llvmValue.appendBasicBlock(name);
    }
    ///
	/// Force a possibly non bool value into a proper bool which
	/// has either all bits set or all bits zeroed.
	///
    LLVMValueRef forceToBool(LLVMValueRef v, Type fromType) {
        if(fromType.isBool) return v;
        auto i1 = builder.icmp(LLVMIntPredicate.LLVMIntNE, v, fromType.zero);
        return castI1ToI8(i1);
    }
    LLVMValueRef castI1ToI8(LLVMValueRef v) {
        if(v.isI1) {
            return builder.sext(v, i8Type());
        }
        return v;
    }
    /*LLVMValueRef castI8ToI1(LLVMValueRef v) {
		if(v.isI8) {
			return builder.trunc(v, i1Type());
		}
        return v;
    }*/
    LLVMValueRef castType(LLVMValueRef v, Type from, Type to, string name=null) {
        dd("cast", from, to);
        if(from==to) return v;
        /// cast to different pointer type
        if(from.isPtr && to.isPtr) {
            rhs = builder.bitcast(v, to.getLLVMType, name);
            return rhs;
        }
        if(from.isPtr && to.isLong) {
            rhs = builder.ptrToInt(v, to.getLLVMType, name);
            return rhs;
        }
        if(from.isLong && to.isPtr) {
            rhs = builder.intToPtr(v, to.getLLVMType, name);
            return rhs;
        }
        /// real->int or int->real
        if(from.isReal != to.isReal) {
            if(!from.isReal) {
                /// int->real
                rhs = builder.sitofp(v, to.getLLVMType, name);
            } else {
                /// real->int
                rhs = builder.fptosi(v, to.getLLVMType, name);
            }
            return rhs;
        }
        /// widen or truncate
        if(from.size < to.size) {
            /// widen
            if(from.isReal) {
                rhs = builder.fpext(v, to.getLLVMType, name);
            } else {
                rhs = builder.sext(v, to.getLLVMType, name);
            }
        } else {
            /// truncate
            if(from.isReal) {
                rhs = builder.fptrunc(v, to.getLLVMType, name);
            } else {
                rhs = builder.trunc(v, to.getLLVMType, name);
            }
        }
        return rhs;
    }
    bool verify() {
        log("Verifying %s", module_.canonicalName);
        if(!module_.llvmValue.verify()) {
            log("=======================================");
            module_.llvmValue.dump();
            log("=======================================");
            log("module %s is invalid", module_.canonicalName);
            //llvmmod.verify();
            return false;
        }
        log("finished verifying");
        return true;
    }
}