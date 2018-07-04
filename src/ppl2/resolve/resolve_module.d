module ppl2.resolve.resolve_module;

import ppl2.internal;

final class ModuleResolver {
private:
    CallResolver callResolver;
    IdentifierResolver identifierResolver;
    StopWatch watch;
    int pass;
    bool addedModuleScopeElements;
    Set!ASTNode unresolved;
public:
    Module module_;

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }
    ASTNode[] getUnresolvedNodes() { return unresolved.values; }

    this(Module module_) {
        this.module_ = module_;
        this.callResolver = new CallResolver(this);
        this.identifierResolver = new IdentifierResolver(this);
        this.unresolved = new Set!ASTNode;
        this.pass = 1;
    }

    ///
    /// Pass through any unresolved nodes and try to resolve them.   
    /// Return number of unresolved elements.                        
    ///
    int resolve() {
        watch.start();

        collectModuleScopeElements();

        unresolved.clear();

        foreach(r; module_.activeRoots.values.dup) {
            recursiveVisit(r);
        }

        //int numUnresolved = (addedModuleScopeElements ? 0 : 1) + unresolved.length;
        int numUnresolved = unresolved.length;

        pass++;
        watch.stop();
        return numUnresolved;
    }
    void resolveFunction(string funcName) {
        watch.start();
        log("Resolving %s func '%s'", module_, funcName);

        collectModuleScopeElements();

        /// Visit all functions at module scope with the right name
        foreach(n; module_.children) {
            auto f = cast(Function)n;
            if(f && f.name==funcName) {
                log("\t  Adding root %s", f);
                module_.activeRoots.add(f);

                /// Don't add local reference here. Add it once we have filtered possible
                /// overload sets down to the one we are going to use.
            }
        }
        watch.stop();
    }
    void resolveDefine(string defineName) {
        watch.start();
        log("Resolving %s define|struct '%s'", module_, defineName);

        collectModuleScopeElements();



        module_.recurse!Define((it) {
            if(it.name==defineName) {
                if(it.parent.isModule) {
                    log("\t  Adding root %s", it);
                    module_.activeRoots.add(it);
                }
                it.numRefs++;
            }
        });
        module_.recurse!NamedStruct((it) {
            if(it.name==defineName) {
                if(it.parent.isModule) {
                    log("\t  Adding root %s", it);
                    module_.activeRoots.add(it);
                }
                it.numRefs++;
            }
        });

        watch.stop();
    }
    //=====================================================================================
    void visit(AddressOf n) {

    }
    void visit(Arguments n) {

    }
    void visit(ArrayType n) {
        resolveType(n.subtype);
    }
    void visit(As n) {

    }
    void visit(Assert n) {

    }
    void visit(Binary n) {
        if(n.type.isUnknown) {

            auto lt = n.leftType();
            auto rt = n.rightType();

            if(lt.isKnown && rt.isKnown) {
                /// If we are assigning then take the type of the lhs expression
                if(n.op.isAssign) {
                    n.type = lt;
                } else if(n.op.isBool) {
                    n.type = TYPE_BOOL;
                } else {
                    /// Set to largest of left or right type
                    auto t = getBestFit(lt, rt);
                    /// Promote byte, short to int
                    if(t.isValue && t.isInteger && t.getEnum < TYPE_INT.getEnum) {
                        n.type = TYPE_INT;
                    } else {
                        n.type = t;
                    }
                }
            }
        }
    }
    void visit(Call n) {
        if(!n.target.isResolved) {

            // todo - handle template function call

            auto overloadSet = new Array!Callable;

            if(n.isStartOfChain()) {

                if(callResolver.find(n.name, n, overloadSet)) {

                    /// Filter out until we only have 1 match
                    callResolver.filterOverloads(n, overloadSet);

                    if(overloadSet.length==0) {
                        throw new CompilerError(Err.FUNCTION_NOT_FOUND, n,
                        "Function %s not found".format(n.name));
                    }
                    if(overloadSet.length > 1) {
                        throw new CompilerError(Err.AMBIGUOUS_CALL, n,
                        "Ambiguous call");
                    }

                    /// If we get here then we have 1 good match
                    auto o = overloadSet[0];
                    auto f = cast(Function)o;
                    if(f) {
                        n.target.set(f);
                    }
                    auto v = cast(Variable)o;
                    if(v) {
                        n.target.set(v);
                    }
                }
            } else {
                Expression prev = n.prevLink();
                Type prevType   = prev.getType;

                if(prevType.isKnown) {
                    if(!prevType.isStruct) throw new CompilerError(Err.MEMBER_NOT_FOUND, prev,
                        "Left of call '%s' must be a struct type not a %s".format(n.name, prevType));

                    AnonStruct struct_ = prevType.getAnonStruct();

                    auto fns   = struct_.getMemberFunctions(n.name);
                    auto var   = struct_.getMemberVariable(n.name);

                    /// Filter
                    foreach(f; fns) overloadSet.add(f);
                    if(var) overloadSet.add(var);
                    callResolver.filterOverloads(n, overloadSet);

                    if(overloadSet.length==0) {
                        throw new CompilerError(Err.FUNCTION_NOT_FOUND, n,
                            "Struct %s does not have function %s".format(struct_, n.name));
                    } else if(overloadSet.length > 1) {
                        throw new CompilerError(Err.AMBIGUOUS_CALL, n,
                            "Ambiguous call");
                    }

                    /// If we get here then we have 1 good match

                    //checkStructMemberAccessIsNotPrivate(struct_, var);

                    auto o = overloadSet[0];
                    auto f = o.as!Function;
                    if(f) {
                        int index = struct_.getMemberIndex(f);
                        if(!n.target.isSet) {
                            n.target.set(f, index);
                        }
                    }
                    auto v = o.as!Variable;
                    if(v) {
                        int index = struct_.getMemberIndex(v);
                        if(!n.target.isSet) {
                            n.target.set(v, index);
                        }
                    }
                }
            }
        }
    }
    void visit(CompositeExpression n) {

    }
    void visit(Constructor n) {
        resolveType(n.type);
    }
    void visit(Define n) {
        resolveType(n.type);
        if(n.type.isAnonStruct) {

        }
    }
    void visit(Dot n) {

    }
    void visit(Function n) {

    }
    void visit(FunctionType n) {

    }
    void visit(Identifier n) {
        if(!n.target.isResolved) {

            if(n.isStartOfChain()) {

                auto var = identifierResolver.findFirstVariable(n.name, n);
                if(!var) {
                    throw new CompilerError(Err.IDENTIFIER_NOT_FOUND, n,
                        "Identifier %s not found".format(n.name));
                }

                /// Is it a struct member variable?
                if(var.isStructMember) {
                    auto struct_ = n.getContainingStruct();
                    assert(struct_);
                    //checkStructMemberAccessIsNotPrivate(struct_, var);
                    //checkForReadOnlyAssignment(struct_, var);
                    int index = struct_.getMemberIndex(var);
                    if(!n.target.isSet) {
                        n.target.set(var, index);
                    }
                } else {
                    /// Global, local or parameter
                    if(!n.target.isSet) {
                        n.target.set(var);
                    }
                }

                /// If var is unknown we need to do some detective work...
                if(var.type.isUnknown && n.parent.isA!Binary) {
                    auto bin = n.parent.as!Binary;
                    if(bin.op == Operator.ASSIGN) {
                        auto opposite = bin.otherSide(n);
                        if(opposite && opposite.getType.isKnown) {
                            var.setType(opposite.getType);
                        }
                    }
                }
            } else {
                /// Find the struct
                Expression prev = n.prevLink();
                Type prevType   = prev.getType;

                if(prevType.isKnown) {
                    if(!prevType.isStruct) throw new CompilerError(Err.MEMBER_NOT_FOUND, prev,
                    "Left of identifier must be a struct type not a %s".format(prevType));

                    AnonStruct struct_ = prevType.getAnonStruct();
                    assert(struct_);

                    auto var = struct_.getMemberVariable(n.name);
                    if(var) {
                        //checkStructMemberAccessIsNotPrivate(struct_, var);
                        //checkForReadOnlyAssignment(struct_, var);
                        int index = struct_.getMemberIndex(var);
                        if(!n.target.isSet) {
                            n.target.set(var, index);
                        }
                    }
                }
            }
        }
    }
    void visit(Initialiser n) {
        n.resolve();

        //if(n.getType.isUnknown) {
        //    Type parentType;
        //    switch(n.parent.id) with(NodeID) {
        //        case VARIABLE:
        //            parentType = n.parent.as!Variable.type;
        //            break;
        //        case BINARY:
        //            parentType = n.parent.as!Binary.otherSide(n).getType;
        //            break;
        //        case LITERAL_FUNCTION:
        //            parentType = n.getInferredType();
        //            break;
        //        case INITIALISER:
        //            parentType = n.parent.as!Initialiser.getType;
        //            break;
        //        default:
        //            assert(false, "Parent of Initialiser is %s".format(n.parent.id));
        //    }
        //    if(parentType && parentType.isKnown) {
        //        auto type = parentType.getAnonStruct;
        //        if(type) {
        //            n.type = type;
        //        }
        //    }
    }
    void visit(Index n) {

    }
    void visit(LiteralArray n) {
        if(n.type.isUnknown) {

            Type parentType;
            switch(n.parent.id) with(NodeID) {
                case VARIABLE:
                    parentType = n.parent.as!Variable.type;
                    break;
                case BINARY:
                    parentType = n.parent.as!Binary.otherSide(n).getType;
                    break;
                case INITIALISER:
                    parentType = n.parent.as!Initialiser.getType;
                    break;
                default:
                    assert(false, "Parent of LiteralArray is %s".format(n.parent.id));
            }
            if(parentType && parentType.isKnown) {
                auto type = parentType.getArrayType;
                if(type) {
                    n.type = type;
                }
            }

            if(n.type.isUnknown) {
                n.inferTypeFromElements();
            }
        } else {
            /// Make sure we have the same subtype as our parent
            if(n.parent.getType.isKnown) {
                //auto arrayType = n.parent.getType().getArrayType;
                //assert(arrayType, "Expecting ArrayType, got %s".format(n.parent.getType()));

                //n.type.subtype = arrayType.subtype;
            }
        }
        //if(n.type.isKnown) {
        //    if(n.isArray) {
        //        /// Check that element type matches
        //
        //        auto eleType = n.type.getArrayType.subtype;
        //        //auto t       = n.calculateElementType(eleType);
        //
        //        foreach(i, t; n.elementTypes()) {
        //            if(!t.canImplicitlyCastTo(eleType)) {
        //                throw new CompilerError(Err.BAD_IMPLICIT_CAST, n.children[i],
        //                    "Expecting an array of %s. Cannot implicitly cast %s to %s".format(eleType, t, eleType));
        //            }
        //        }
        //
        //    } else {
        //
        //    }
        //}
    }
    void visit(LiteralFunction n) {
        if(n.type.isUnknown) {
            auto ty = cast(FunctionType)n.type;
            if(ty.returnType.isUnknown) {
                ty.returnType = n.determineReturnType();
            }
            foreach(i, a; ty.argTypes) {
                if(a.isUnknown) {
                    /// Set arg type from child arg Variable
                    auto arg = n.args.getArg(i);
                    if(arg.type.isKnown) {
                        ty.argTypes[i] = arg.type;
                    }
                }
            }
        }
    }
    void visit(LiteralMap n) {
        assert(false, "implement visit.LiteralMap");
    }
    void visit(LiteralNull n) {
        if(n.type.isUnknown) {
            Type t = n.parent.getType();
            if(t.isUnknown) {
                /// Determine type from parent
                switch (n.parent.id()) with(NodeID) {
                    case BINARY:
                        t = n.parent.as!Binary.leftType();
                        break;
                    case VARIABLE:
                        t = n.parent.as!Variable.type;
                        break;
                    case AS:
                        t = n.parent.as!As.getType;
                        break;
                    case INITIALISER:
                        t = n.parent.as!Initialiser.getType;
                        break;
                    default:
                        assert(false, "parent is %s".format(n.parent.id()));
                }
            }
            if(t.isKnown) {
                n.type = t;
            }
        }
    }
    void visit(LiteralNumber n) {
        if(n.type.isUnknown) {
            n.determineType();
        }
    }
    void visit(LiteralString n) {
        if(n.type.isUnknown) {
            resolveType(n.type);
        }
    }
    void visit(LiteralStruct n) {
        if(n.type.isUnknown) {

            if(n.parent.isA!Variable) {
                /// We are the initialiser of a 'var' Variable
                auto t = n.getInferredType();
                if(t) {
                    n.parent.as!Variable.setType(t);
                    n.type = t;
                }
            }

            if(n.type.isUnknown) {
                Type parentType;
                switch(n.parent.id) with(NodeID) {
                    case VARIABLE:
                        parentType = n.parent.as!Variable.type;
                        break;
                    case BINARY:
                        parentType = n.parent.as!Binary.otherSide(n).getType;
                        break;
                    case LITERAL_FUNCTION:
                        parentType = n.getInferredType();
                        break;
                    case INITIALISER:
                        parentType = n.parent.as!Initialiser.getType;
                        if(parentType.isUnknown) {
                            parentType = n.getInferredType();
                        }
                        break;
                    case INDEX:
                        parentType = n.getInferredType();
                        break;
                    default:
                        assert(false, "Parent of LiteralStruct is %s".format(n.parent.id));
                }
                if(parentType && parentType.isKnown) {
                    auto type = parentType.getAnonStruct;
                    if(type) {
                        n.type = type;
                    }
                }
            }
        }
    }
    void visit(NamedStruct n) {

    }
    void visit(Malloc n) {
        resolveType(n.valueType);
    }
    void visit(Module n) {

    }
    void visit(Parenthesis n) {

    }
    void visit(Return n) {

    }
    void visit(AnonStruct n) {

    }
    void visit(TypeExpr n) {
        resolveType(n.type);
    }
    void visit(Unary n) {

    }
    void visit(ValueOf n) {

    }
    void visit(Variable n) {

        resolveType(n.type);

        if(n.type.isUnknown) {

            if(n.hasInitialiser) {
                /// Get the type from the initialiser
                if(n.initialiserType().isKnown) {
                    n.setType(n.initialiserType());
                }
            } else {
                /// No initialiser
                if(n.type.isArray && n.type.getArrayType.inferCount) {
                    throw new CompilerError(Err.INFER_ARRAY_WITHOUT_INITIALISER, n,
                        "Array with inferred count must have an initialiser");
                }
            }

            //if(n.isGlobal() || n.isStructMember()) {
            //    dd(n.name, n.type);
            //
            //    throw new CompilerError(Err.VAR_MUST_HAVE_EXPLICIT_TYPE, n,
            //      "Globals or struct member variables must have explicit type");
            //}
        }
        if(n.type.isKnown) {
            /// Allow a double literal initialiser to be interpreted as a float or half
            if(n.type.isReal && n.type.isValue && n.hasInitialiser) {
                auto lit = n.initialiser.literal;
                if(lit) {
                    lit.type = n.type;
                }
            }
        }
    }
    //==========================================================================
    void writeAST() {
        if(!getConfig().logDebug) return;

        //dd("DUMP MODULE", module_);

        auto f = new FileLogger(getConfig().targetPath~"ast/" ~ module_.canonicalName~".ast");
        scope(exit) f.close();

        module_.dump(f);
        f.log("==============================================");
        f.log("======================== Unresolved Nodes (%s)", unresolved.length);

        foreach (i, n; unresolved.values) {
            f.log("\t[%s] Line %s %s", i, n.line, n);
        }
        f.log("==============================================");
    }
//==========================================================================
private:
    void recursiveVisit(ASTNode m) {
        dd("resolve", typeid(m), m.nid);
        m.visit!ModuleResolver(this);

        if(!m.isResolved) {
            unresolved.add(m);
        }

        foreach(n; m.children) {
            recursiveVisit(n);
        }
    }
    ///
    /// If this is the first time we have looked at this module then add           
    /// all module level variables to the list of roots to resolve
    ///
    void collectModuleScopeElements() {
        if(!addedModuleScopeElements && module_.isParsed) {
            addedModuleScopeElements = true;

            foreach(n; module_.getVariables()) {
                module_.activeRoots.add(n);
            }
        }
    }
    ///
    /// If type is a Define then we need to resolve it and import it if it is
    /// not within the same module.
    ///
    void resolveType(ref Type type) {

        if(type.isDefine) {

            auto def = type.getDefine;
            defineRequired(def.moduleName, def.name);

            if(!def.isImport) {
                /// Convert this Define to it's proper type
                if(def.isKnown) type = PtrType.of(def.getRootType, type.getPtrDepth);
                return;
            }
            if(type.isKnown) return;

            auto m = PPL2.getModule(def.moduleName);
            if(m && m.isParsed) {
                /// Swap the define to the one in the imported module
                auto externDef = m.getDefine(def.name);
                if(externDef) {
                    type = PtrType.of(externDef.getRootType, type.getPtrDepth);
                    //externDef.numRefs++;
                } else {
                    auto ns = m.getNamedStruct(def.name);
                    if(ns) {
                        type = PtrType.of(ns, type.getPtrDepth);
                    } else {
                        throw new CompilerError(Err.IMPORT_NOT_FOUND, module_,
                            "Import %s not found in module %s".format(def.name, def.moduleName));
                    }
                }
            }
        } else if(type.isNamedStruct) {
            auto ns = type.getNamedStruct;
            defineRequired(module_.canonicalName, ns.name);
        }
    }
}