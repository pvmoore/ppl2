module ppl2.gen.gen_module;

import ppl2.internal;

final class ModuleGenerator {
public:
    Module module_;
    StopWatch watch;
    BinaryGenerator binaryGen;
    LiteralGenerator literalGen;
    IfGenerator ifGen;
    SelectGenerator selectGen;
    LoopGenerator loopGen;

    LLVMWrapper llvm;
    LLVMBuilder builder;
    LLVMValueRef lhs;
    LLVMValueRef rhs;
    LLVMBasicBlockRef currentBlock;

    LLVMValueRef memsetFunc;
    LLVMValueRef expectBoolFunc;
    //LLVMValueRef memcmpFunc;

    LLVMValueRef[string] structMemberThis;  /// key = struct.getUniqueName

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    this(Module module_, LLVMWrapper llvm) {
        this.module_    = module_;
        this.llvm       = llvm;
        this.builder    = llvm.builder;
        this.binaryGen  = new BinaryGenerator(this);
        this.literalGen = new LiteralGenerator(this);
        this.ifGen      = new IfGenerator(this);
        this.selectGen  = new SelectGenerator(this);
        this.loopGen    = new LoopGenerator(this);
    }
    void clearState() {
        watch.reset();
    }
    bool generate() {
        watch.start();
        log("Generating IR for module %s", module_.canonicalName);

        this.lhs = null;
        this.rhs = null;

        if(module_.llvmValue !is null) {
           module_.llvmValue.destroy();
        }
        module_.llvmValue = llvm.createModule(module_.canonicalName);

        generateGlobalStrings();
        generateLocalGlobalVariableDeclarations(module_);
        generateLocalStaticVariableDeclarations(module_);
        generateImportedStaticVariableDeclarations(module_);

        generateImportedStructDeclarations(module_);
        generateLocalStructDeclarations(module_);

        generateLocalEnumDeclarations(module_);
        generateImportedEnumDeclarations(module_);

        generateIntrinsicFuncDeclarations();
        generateStandardFunctionDeclarations(module_);
        generateImportedFunctionDeclarations(module_);
        generateClosureDeclarations(module_);
        generateLocalStructFunctionDeclarations(module_);
        generateInnerFunctionDeclarations(module_);

        generateLocalStructMemberFunctionBodies(module_, literalGen);
        generateClosureBodies(module_, literalGen);
        generateInnerFunctionBodies(module_, literalGen);

        visitChildren(module_);

        writeLL(module_, "ir/");

        bool result = verify();
        watch.stop();
        return result;
    }
    //======================================================================================
    void visit(AddressOf n) {
        n.expr().visit!ModuleGenerator(this);

        rhs = lhs;
    }
    void visit(AnonStruct n) {

    }
    void visit(As n) {
        n.left.visit!ModuleGenerator(this);

        rhs = castType(rhs, n.left().getType, n.getType, "as");
    }
    void visit(Binary n) {
        binaryGen.generate(n);
    }
    void visit(Break n) {
        loopGen.generate(n);
    }
    void visit(Call n) {
        Type returnType       = n.target.returnType;
        Type[] funcParamTypes = n.target.paramTypes;
        LLVMValueRef[] argValues;

        foreach(i, e; n.children[]) {
            e.visit!ModuleGenerator(this);
            argValues ~= castType(rhs, e.getType, funcParamTypes[i]);
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

            //if(rhs.getType.isPointer) {
            //    int index = n.target.structMemberIndex;
            //    lhs = builder.getElementPointer_struct(rhs, index);
            //}

        } else if(n.target.isVariable) {
            rhs = builder.load(n.target.llvmValue);
            rhs = builder.call(rhs, argValues, LLVMCallConv.LLVMFastCallConv);
        } else if(n.target.isFunction) {
            assert(n.target.llvmValue, "Function llvmValue is null: %s".format(n.target.getFunction));
            rhs = builder.call(n.target.llvmValue, argValues, n.target.getFunction().getCallingConvention());
        }

        if((returnType.isNamedStruct || returnType.isAnonStruct) &&
           (n.parent.isDot || n.parent.isA!Parenthesis) &&
           !returnType.isPtr)
        {
            /// Special case for returning struct values.
            /// We need to store the result locally
            /// so that we can take a pointer to it
            lhs = builder.alloca(returnType.getLLVMType(), "retValStorage");
            builder.store(rhs, lhs);
        }
    }
    void visit(Calloc n) {
        rhs = builder.malloc(n.valueType.getLLVMType(), "calloc");
        memsetZero(rhs, n.valueType.size);
    }
    void visit(Closure n) {
        assert(n.llvmValue);
        rhs = n.llvmValue;
    }
    void visit(Composite n) {
        visitChildren(n);
    }
    void visit(Continue n) {
        loopGen.generate(n);
    }
    void visit(Constructor n) {
        visitChildren(n);
    }
    void visit(Dot n) {
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
    void visit(Enum n) {

    }
    void visit(EnumMember n) {
        auto enum_    = n.type;
        auto llvmType = enum_.getLLVMType;
        assert(llvmType);

        n.expr().visit!ModuleGenerator(this);
        auto elementValue = castType(rhs, n.expr().getType, enum_.elementType);

        if(isConst(elementValue)) {
            rhs = constNamedStruct(llvmType, [elementValue]);
        } else {
            /// Do it the long-winded way
            lhs = builder.alloca(llvmType, "temp_enum");
            rhs = builder.insertValue(builder.load(lhs), elementValue, 0);
        }
    }
    void visit(EnumMemberValue n) {

        n.expr().visit!ModuleGenerator(this);

        rhs = builder.extractValue(rhs, 0);
    }
    void visit(ExpressionRef n) {
        n.expr().visit!ModuleGenerator(this);
    }
    void visit(Function n) {
        if(n.isExtern) return;
        if(n.isInner) return;

        assert(n.llvmValue);
        n.getBody().visit!ModuleGenerator(this);
    }
    void visit(Identifier n) {
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
            assert(n.target.llvmValue);

            rhs = n.target.llvmValue;
        } else if(n.target.isVariable) {
            assert(n.target.llvmValue);
            lhs = n.target.llvmValue;
            rhs = builder.load(lhs);
        }
    }
    void visit(If n) {
        ifGen.generate(n);
    }
    void visit(Index n) {
        n.index().visit!ModuleGenerator(this);
        rhs = castType(rhs, n.index().getType, TYPE_INT, "cast");
        LLVMValueRef arrayIndex = rhs;

        n.expr().visit!ModuleGenerator(this);

        if(n.isArrayIndex) {

            auto indices = [constI32(0), arrayIndex];
            lhs = builder.getElementPointer_inBounds(lhs, indices);

        } else if(n.isStructIndex) {
            // todo - handle "this"?

            lhs = builder.getElementPointer_struct(lhs, n.getIndexAsInt());

        } else if(n.isPtrIndex) {

            auto indices = [arrayIndex];
            lhs = builder.getElementPointer_inBounds(rhs, indices);

        } else assert(false);

        rhs = builder.load(lhs);
    }
    void visit(Initialiser n) {
        visitChildren(n);
    }
    void visit(Is n) {
        n.left.visit!ModuleGenerator(this);
        auto left = castType(rhs, n.leftType(), n.rightType());

        n.right.visit!ModuleGenerator(this);
        auto right = rhs;

        auto predicate = n.negate ? LLVMIntPredicate.LLVMIntNE : LLVMIntPredicate.LLVMIntEQ;

        auto cmp = builder.icmp(predicate, left, right);
        rhs = castI1ToI8(cmp);
    }
    void visit(LiteralArray n) {
        literalGen.generate(n);
    }
    void visit(LiteralFunction n) {
        assert(!n.isClosure);
        literalGen.generate(n, n.getLLVMValue);
    }
    void visit(LiteralNull n) {
        literalGen.generate(n);
    }
    void visit(LiteralNumber n) {
        literalGen.generate(n);
    }
    void visit(LiteralString n) {
        literalGen.generate(n);
    }
    void visit(LiteralStruct n) {
        literalGen.generate(n);
    }
    void visit(Loop n) {
        loopGen.generate(n);
    }
    void visit(ModuleAlias n) {

    }
    void visit(NamedStruct n) {

    }
    void visit(Parameters n) {
        auto litFunc   = n.getLiteralFunction();
        auto llvmValue = litFunc.getLLVMValue();
        auto params    = getFunctionParams(llvmValue);

        foreach(i, v; n.getParams()) {
            v.visit!ModuleGenerator(this);
            builder.store(params[i], lhs);

            /// Remember values of "this" so that we can access member variables later
            if(v.name=="this") {
                auto struct_ = v.type.getNamedStruct;
                assert(struct_);

                rhs = builder.load(lhs, "this");
                structMemberThis[struct_.getUniqueName] = params[i]; // rhs
            }
        }
    }
    void visit(Parenthesis n) {
        n.expr().visit!ModuleGenerator(this);
    }
    void visit(Return n) {
        if(n.hasExpr) {
            n.expr().visit!ModuleGenerator(this);
            rhs = castType(rhs, n.expr().getType, n.getReturnType());
            builder.ret(rhs);
        } else {
            builder.retVoid();
        }
    }
    void visit(Select n) {
        selectGen.generate(n);
    }
    void visit(TypeExpr n) {
        /// ignore
    }
    void visit(Unary n) {

        n.expr().visit!ModuleGenerator(this);

        if(n.op is Operator.BOOL_NOT) {
            rhs = forceToBool(rhs, n.expr().getType);
            rhs = builder.not(rhs, "not");
        } else if(n.op is Operator.BIT_NOT) {
            rhs = builder.not(rhs, "not");
        } else if(n.op is Operator.NEG) {
            auto op = n.getType.isReal ? LLVMOpcode.LLVMFSub : LLVMOpcode.LLVMSub;
            rhs = builder.binop(op, n.expr().getType.zeroValue, rhs);
        }
    }
    void visit(ValueOf n) {
        n.expr().visit!ModuleGenerator(this);

        lhs = builder.getElementPointer_inBounds(rhs, [constI32(0)]);
        rhs = builder.load(rhs, "valueOf");
    }
    void visit(Variable n) {
        if(n.isGlobal) {

        } else if(n.isAnonStructMember) {

        } else if(n.isNamedStructMember) {

        } else {
            //// it must be a local/parameter

            lhs = builder.alloca(n.type.getLLVMType(), n.name);

            // todo - can we remove this?
            n.llvmValue = lhs;

            //setAlignment(lhs, 4);

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
            //dd("visit", ch.id);
            ch.visit!ModuleGenerator(this);
        }
    }
    void generateGlobalStrings() {
        foreach(LiteralString[] array; module_.getLiteralStrings()) {
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
        // void (i8*, i8, i32, i1)* @llvm.memset.p0i8.i32
        memsetFunc = module_.llvmValue.addFunction(
            "llvm.memset.p0i8.i32",
            voidType(),
            [bytePointerType(), i8Type(), i32Type(), i1Type()],
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
    void memsetZero(LLVMValueRef ptr, int len) {
        auto i8Ptr = builder.bitcast(ptr, bytePointerType());
        auto args = [
            i8Ptr, constI8(0), constI32(len), constI1(0)
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
        auto body_ = n.getAncestor!LiteralFunction();
        assert(body_);
        return body_.getLLVMValue().appendBasicBlock(name);
    }
    void moveToBlock(LLVMBasicBlockRef label) {
        builder.positionAtEndOf(label);
        currentBlock = label;
    }
    ///
	/// Force a possibly non bool value into a proper bool which
	/// has either all bits set or all bits zeroed.
	///
    LLVMValueRef forceToBool(LLVMValueRef v, Type fromType) {
        if(fromType.isBool) return v;
        auto i1 = builder.icmp(LLVMIntPredicate.LLVMIntNE, v, fromType.zeroValue, "tobool");
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
        if(from.exactlyMatches(to)) return v;
        //dd("cast", from, to);
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
        } else if(from.size > to.size) {
            /// truncate
            if(from.isReal) {
                rhs = builder.fptrunc(v, to.getLLVMType, name);
            } else {
                rhs = builder.trunc(v, to.getLLVMType, name);
            }
        } else {
            /// Size is the same
            assert(from.isAnonStruct, "castType size is the same - from %s to %s".format(from, to));
            assert(to.isAnonStruct);
            assert(false, "we shouldn't get here");
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