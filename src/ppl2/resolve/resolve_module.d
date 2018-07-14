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
    Array!Callable overloadSet;
public:
    Module module_;

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }
    ASTNode[] getUnresolvedNodes() { return unresolved.values; }

    this(Module module_) {
        this.module_            = module_;
        this.callResolver       = new CallResolver(module_);
        this.identifierResolver = new IdentifierResolver(module_);
        this.unresolved         = new Set!ASTNode;
        this.overloadSet        = new Array!Callable;
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

                /// Don't add reference here. Add it once we have filtered possible
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
    void visit(AnonStruct n) {

    }
    void visit(ArrayType n) {
        resolveType(n.subtype);
    }
    void visit(As n) {

    }
    void visit(Assert n) {
        if(!n.isResolved) {

            /// This should eventually be imported implicitly
            assert(module_.getFunctions("__assert"), "import core.intrinsics");
            //assert(module_.getDefine("string") || module_.getNamedStruct("string"), "import core.string");

            /// Wait until we know what the type is
            Type type = n.expr().getType();
            if(type.isUnknown) return;

            /// Convert to a call to __assert(bool, string, int)
            auto parent = n.parent;
            auto b      = module_.builder(n);

            auto c = b.call("__assert", null);
            parent.replaceChild(n, c);

            /// value
            Expression value;
            if(type.isPtr) {
                value = b.binary(Operator.BOOL_NE, n.expr(), LiteralNull.makeConst(type));
            } else if(type.isBool) {
                value = n.expr();
            } else {
                value = b.binary(Operator.BOOL_NE, n.expr(), LiteralNumber.makeConst(0));
            }
            c.addToEnd(value);

            /// string
            //c.addToEnd(b.string_(module_.moduleNameLiteral));
            c.addToEnd(module_.moduleNameLiteral.copy());

            /// line
            c.addToEnd(LiteralNumber.makeConst(n.line, TYPE_INT));
        }
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

            if(n.isStartOfChain()) {

                auto callable = callResolver.find(n.name, n.argTypes(), n);
                if(callable) {
                    /// If we get here then we have 1 good match
                    auto o = callable;
                    auto f = o.as!Function;
                    if(f) {
                        n.target.set(f);
                    }
                    auto v = o.as!Variable;
                    if(v) {
                        n.target.set(v);
                    }
                }

            } else {
                Expression prev = n.prevLink();
                assert(prev);
                Type prevType   = prev.getType;

                if(prevType.isKnown) {
                    if(!prevType.isStruct) throw new CompilerError(Err.MEMBER_NOT_FOUND, prev,
                        "Left of call '%s' must be a struct type not a %s".format(n.name, prevType));

                    AnonStruct struct_ = prevType.getAnonStruct();

                    auto fns   = struct_.getMemberFunctions(n.name);
                    auto var   = struct_.getMemberVariable(n.name);

                    /// Filter
                    overloadSet.clear();
                    foreach(f; fns) overloadSet.add(f);
                    if(var) overloadSet.add(var);
                    callResolver.filterOverloads(n.argTypes(), overloadSet);

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
                        n.target.set(f, struct_.getMemberIndex(f));
                    }
                    auto v = o.as!Variable;
                    if(v) {
                        n.target.set(v, struct_.getMemberIndex(v));
                    }
                }
            }
        }
    }
    void visit(Closure n) {

    }
    void visit(Composite n) {

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

                auto res = identifierResolver.findFirst(n.name, n);
                if(!res.found) {
                    throw new CompilerError(Err.IDENTIFIER_NOT_FOUND, n,
                        "%s not found".format(n.name));
                }

                if(res.isFunc) {
                    auto func = res.func;

                    functionRequired(func.moduleName, func.name);

                    if(func.isStructMember) {
                        auto struct_ = n.getContainingStruct();
                        assert(struct_);
                        //checkStructMemberAccessIsNotPrivate(struct_, func);
                        //checkForReadOnlyAssignment(struct_, func);
                        n.target.set(func, struct_.getMemberIndex(func));
                    } else {
                        /// Global, local or parameter
                        n.target.set(func);
                    }
                } else {
                    Variable var = res.isVar ? res.var : null;

                    if (var.isStructMember) {
                        auto struct_ = n.getContainingStruct();
                        assert(struct_);
                        //checkStructMemberAccessIsNotPrivate(struct_, var);
                        //checkForReadOnlyAssignment(struct_, var);
                        n.target.set(var, struct_.getMemberIndex(var));
                    } else {
                        /// Global, local or parameter
                        n.target.set(var);
                    }

                    /// If var is unknown we need to do some detective work...
                    if (var.type.isUnknown && n.parent.isA!Binary) {
                        auto bin = n.parent.as!Binary;
                        if (bin.op == Operator.ASSIGN) {
                            auto opposite = bin.otherSide(n);
                            if (opposite && opposite.getType.isKnown) {
                                var.setType(opposite.getType);
                            }
                        }
                    }
                }
            } else {
                /// Find the struct
                Expression prev = n.prevLink();
                Type prevType   = prev.getType;

                if(prevType.isKnown) {

                    /// Current structure:
                    ///
                    /// Dot
                    ///    prev
                    ///    ptr
                    ///
                    auto dot = n.parent.as!Dot;
                    assert(dot);

                    /// Properties:
                    switch(n.name) {
                        case "length":
                            if(prevType.isArray) {
                                int len = prevType.getArrayType.countAsInt();
                                dot.parent.replaceChild(dot, LiteralNumber.makeConst(len, TYPE_INT));
                                return;
                            }
                            break;
                        case "subtype":
                            if(prevType.isArray) {
                                dot.parent.replaceChild(dot, TypeExpr.make(prevType.getArrayType.subtype));
                                return;
                            }
                            break;
                        case "ptr":
                            if(prevType.isArray) {
                                if(prevType.isPtr) {
                                    assert(false, "array is a pointer. handle this");
                                }

                                auto b = module_.builder(n);
                                auto as = b.as(b.addressOf(prev), PtrType.of(prevType.getArrayType.subtype, 1));
                                /// As
                                ///   AddressOf
                                ///      prev
                                /// subtype*
                                dot.parent.replaceChild(dot, as);
                                return;
                            }
                            break;
                        case "#size": {
                            int size = prevType.size();
                            dot.parent.replaceChild(dot, LiteralNumber.makeConst(size, TYPE_INT));
                            return;
                        }
                        default:
                            break;
                    }


                    if(!prevType.isStruct) {
                        throw new CompilerError(Err.MEMBER_NOT_FOUND, prev,
                            "Left of identifier must be a struct type not a %s".format(prevType));
                    }

                    AnonStruct struct_ = prevType.getAnonStruct();
                    assert(struct_);

                    auto var = struct_.getMemberVariable(n.name);
                    if(var) {
                        //checkStructMemberAccessIsNotPrivate(struct_, var);
                        //checkForReadOnlyAssignment(struct_, var);
                        n.target.set(var, struct_.getMemberIndex(var));
                    }
                }
            }
        }
    }
    void visit(If n) {
        if(!n.isResolved) {
            if(!n.isUsedAsExpr) {
                n.type = TYPE_VOID;
                return;
            }
            if(!n.hasThen) {
                n.type = TYPE_VOID;
                return;
            }

            auto thenType = n.thenType();
            if(thenType.isUnknown) return;

            if(n.hasElse) {
                auto elseType = n.elseType();
                if(elseType.isUnknown) return;

                auto t = getBestFit(thenType, elseType);
                if(!t) {
                    throw new CompilerError(Err.IF_TYPES_NO_NOT_MATCH, n,
                        "%s and %s are incompatible as if result".format(thenType, elseType));
                }

                n.type = t;

            } else {
                n.type = thenType;
            }
        }
    }
    void visit(Index n) {

    }
    void visit(Initialiser n) {
        n.resolve();
    }
    void visit(Is n) {
        n.resolve();
    }
    void visit(LiteralArray n) {
        if(n.type.isUnknown) {
            Type parentType;
            switch(n.parent.id) with(NodeID) {
                case ADDRESS_OF:
                    break;
                case AS:
                    parentType = n.parent.as!As.getType;
                    break;
                case BINARY:
                    parentType = n.parent.as!Binary.otherSide(n).getType;
                    break;
                case CALL: {
                    auto call = n.parent.as!Call;
                    if(call.isResolved) {
                        parentType = call.target.paramTypes()[n.index()];
                    }
                    break;
                }
                case DOT:
                    break;
                case INDEX:
                    break;
                case INITIALISER:
                    parentType = n.parent.as!Initialiser.getType;
                    break;
                case IS:

                    break;
                case LITERAL_FUNCTION:
                    break;
                case VARIABLE:
                    parentType = n.parent.as!Variable.type;
                    break;
                default:
                    assert(false, "Parent of LiteralArray is %s".format(n.parent.id));
            }
            if(parentType && parentType.isKnown) {
                auto type = parentType.getArrayType;
                if(type) {
                    if(!type.isArray) {
                        throw new CompilerError(Err.BAD_IMPLICIT_CAST, n,
                            "Cannot cast array literal to %s".format(type.prettyString));
                    }
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
            auto ty = n.type.getFunctionType;
            if(ty.returnType.isUnknown) {
                ty.returnType = n.determineReturnType();
            }
            foreach(i, a; ty.paramTypes) {
                if(a.isUnknown) {
                    /// Set param type from child param Variable
                    auto param = n.params().getParam(i);
                    if(param.type.isKnown) {
                        ty.paramTypes[i] = param.type;
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
            Type type;
            /// Determine type from parent
            switch(n.parent.id()) with(NodeID) {
                case AS:
                    type = n.parent.as!As.getType;
                    break;
                case BINARY:
                    type = n.parent.as!Binary.leftType();
                    break;
                case COMPOSITE:
                    break;
                case IF:
                    auto if_ = n.parent.as!If;
                    if(if_.hasThen && if_.hasElse) {
                        if(n.nid==if_.thenStmt().nid) {
                            type = if_.elseType();
                        } else {
                            type = if_.thenType();
                        }
                    }
                    break;
                case INITIALISER:
                    type = n.parent.as!Initialiser.getType;
                    break;
                case IS:
                    type = n.parent.as!Is.oppositeSideType(n);
                    break;
                case VARIABLE:
                    type = n.parent.as!Variable.type;
                    break;
                default:
                    assert(false, "parent is %s".format(n.parent.id()));
            }

            if(type && type.isKnown) {
                if(type.isPtr) {
                    n.type = type;
                } else {
                    errorBadNullCast(n, type);
                }
            }
        }
    }
    void visit(LiteralNumber n) {
        if(n.type.isUnknown) {
            n.determineType();
        }
        if(n.type.isKnown) {

        }
    }
    void visit(LiteralString n) {
        if(n.type.isUnknown) {
            resolveType(n.type);
        }
    }
    void visit(LiteralStruct n) {
        if(n.type.isUnknown) {
            Type type;
            /// Determine type from parent
            switch(n.parent.id) with(NodeID) {
                case AS:
                    type = n.parent.as!As.getType;
                    break;
                case BINARY:
                    type = n.parent.as!Binary.otherSide(n).getType;
                    break;
                case CALL: {
                    auto call = n.parent.as!Call;
                    if(call.isResolved) {
                        type = call.target.paramTypes()[n.index()];
                    }
                    break;
                }
                case INITIALISER:
                    type = n.parent.as!Initialiser.getType;
                    if(type.isUnknown) {
                        type = n.getInferredType();
                    }
                    break;
                case INDEX:
                    type = n.getInferredType();
                    break;
                case LITERAL_FUNCTION:
                    type = n.getInferredType();
                    break;
                case VARIABLE:
                    type = n.parent.as!Variable.type;
                    break;
                default:
                    assert(false, "Parent of LiteralStruct is %s".format(n.parent.id));
            }
            if(type && type.isKnown) {
                if(!type.isAnonStruct) {
                    throw new CompilerError(Err.BAD_IMPLICIT_CAST, n,
                        "Cannot cast struct literal to %s".format(type.prettyString));
                }
                n.type = type;
            }
        }
    }
    void visit(Malloc n) {
        resolveType(n.valueType);
    }
    void visit(Module n) {

    }
    void visit(NamedStruct n) {

    }
    void visit(Parameters n) {

    }
    void visit(Parenthesis n) {

    }
    void visit(Return n) {

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
                if(n.type.isArray && !n.type.getArrayType.hasCountExpr()) {
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
        //dd("resolve", typeid(m), m.nid);
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