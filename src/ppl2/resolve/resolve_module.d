module ppl2.resolve.resolve_module;

import ppl2.internal;

final class ModuleResolver {
private:
    CallResolver callResolver;
    IdentifierResolver identifierResolver;
    StopWatch watch;
    Set!ASTNode unresolved;
    Array!Callable overloadSet;
    bool addedModuleScopeElements;
    int rewrites;
    int typesWaiting;
public:
    Module module_;

    ulong getElapsedNanos()        { return watch.peek().total!"nsecs"; }
    ASTNode[] getUnresolvedNodes() { return unresolved.values; }

    this(Module module_) {
        this.module_            = module_;
        this.callResolver       = new CallResolver(module_);
        this.identifierResolver = new IdentifierResolver(module_);
        this.unresolved         = new Set!ASTNode;
        this.overloadSet        = new Array!Callable;
    }
    void clearState() {
        watch.reset();
        unresolved.clear();
        overloadSet.clear();
        addedModuleScopeElements = false;
    }

    ///
    /// Pass through any unresolved nodes and try to resolve them.   
    /// Return number of unresolved elements.                        
    ///
    int resolve() {
        watch.start();
        rewrites     = 0;
        typesWaiting = 0;

        collectModuleScopeElements();

        unresolved.clear();

        foreach(r; module_.getCopyOfActiveRoots()) {
            recursiveVisit(r);
        }

        int numUnresolved = unresolved.length + rewrites + typesWaiting;

        watch.stop();
        return numUnresolved;
    }
    void resolveFunction(string funcName) {
        watch.start();
        log("Resolving %s func '%s'", module_, funcName);

        /// Visit all functions at module scope with the right name
        foreach(n; module_.children) {
            auto f = cast(Function)n;
            if(f && f.name==funcName) {
                log("\t  Adding Function root %s", f);
                module_.addActiveRoot(f);

                /// Don't add reference here. Add it once we have filtered possible
                /// overload sets down to the one we are going to use.
            }
        }
        watch.stop();
    }
    void resolveAliasOrStruct(string AliasName) {
        watch.start();
        log("Resolving %s Alias|struct '%s'", module_, AliasName);

        module_.recurse!Alias((it) {
            if(it.name==AliasName) {
                if(it.parent.isModule) {
                    log("\t  Adding Alias root %s", it);
                    //module_.addActiveRoot(it);
                }
                module_.addActiveRoot(it);
                it.numRefs++;

                /// Could be a chain of Aliases in different modules
                if(it.isImport) {
                    module_.buildState.aliasOrStructRequired(it.moduleName, it.name);
                }
            }
        });
        module_.recurse!NamedStruct((it) {
            if(it.name==AliasName) {
                if(it.parent.isModule) {
                    log("\t  Adding NamedStruct root %s", it);
                    //module_.addActiveRoot(it);
                }
                module_.addActiveRoot(it);
                it.numRefs++;
            }
        });

        watch.stop();
    }
    //=====================================================================================
    void visit(AddressOf n) {
        if(n.expr.id==NodeID.VALUE_OF) {
            auto valueof = n.expr.as!ValueOf;
            auto child   = valueof.expr;
            fold(n, child);
            return;
        }
    }
    void visit(AnonStruct n) {

    }
    void visit(ArrayType n) {
        resolveAlias(n, n.subtype);
    }
    void visit(As n) {
        auto lt = n.leftType();
        auto rt = n.rightType();

        if(lt.isKnown && rt.isKnown) {

            bool isValidRewrite(Type t) {
                return t.isValue && (t.isAnonStruct || t.isArray || t.isNamedStruct);
            }

            if(isValidRewrite(lt) && isValidRewrite(rt)) {
                if(!lt.exactlyMatches(rt)) {
                    /// AnonStruct value -> AnonStruct value

                    /// This is a reinterpret cast

                    /// Rewrite:
                    ///------------
                    /// As
                    ///    left
                    ///    right
                    ///------------
                    /// ValueOf type=rightType
                    ///    As
                    ///       AddressOf
                    ///          left
                    ///       AddressOf
                    ///          right

                    auto b = module_.builder(n);
                    auto p = n.parent;

                    auto value = makeNode!ValueOf(n);

                    fold(n, value);

                    auto left  = b.addressOf(n.left);
                    auto right = b.addressOf(n.right);
                    n.add(left);
                    n.add(right);

                    value.add(n);

                    return;
                }
            }
        }
        if(n.isResolved) {
            /// If cast is unnecessary then just remove the As
            if(lt.exactlyMatches(rt)) {
                fold(n, n.left);
                return;
            }

            /// If left is a literal number then do the cast now
            auto lit = n.left().as!LiteralNumber;
            if(lit && rt.isValue) {

                lit.value.as(rt);
                lit.str = lit.value.getString();

                fold(n, lit);
                return;
            }
        }
    }
    void visit(Assert n) {
        if(!n.isResolved) {

            /// This should be imported implicitly
            assert(findImportByCanonicalName("core::hooks", n));

            /// Wait until we know what the type is
            Type type = n.expr().getType();
            if(type.isUnknown) return;

            /// Convert to a call to __assert(bool, string, int)
            auto parent = n.parent;
            auto b      = module_.builder(n);

            auto c = b.call("__assert", null);

            fold(n, c);

            /// value
            Expression value;
            if(type.isPtr) {
                value = b.binary(Operator.COMPARE, n.expr(), LiteralNull.makeConst(type));
            } else if(type.isBool) {
                value = n.expr();
            } else {
                value = b.binary(Operator.COMPARE, n.expr(), LiteralNumber.makeConst(0));
            }
            c.add(value);

            /// string
            //c.add(b.string_(module_.moduleNameLiteral));
            c.add(module_.moduleNameLiteral.copy());

            /// line
            c.add(LiteralNumber.makeConst(n.line+1, TYPE_INT));

            return;
        }
        /// If the asserted expression is now a const number then
        /// evaluate it now and replace the assert with a true or false
        if(n.expr().isResolved) {
            auto lit = n.expr().as!LiteralNumber;
            if(lit) {
                if(lit.value.getBool()==false) {
                    module_.addError(n, "Assertion failed", true);
                    return;
                }

                fold(n, lit);
            }
        }
    }
    void visit(Binary n) {
        auto lt = n.leftType();
        auto rt = n.rightType();

        if(n.op==Operator.BOOL_AND) {
            auto p = n.parent.as!Binary;
            if(p && p.op==Operator.BOOL_OR) {
                module_.addError(n, "Parenthesis required to disambiguate these expressions", true);
            }
        }
        if(n.op==Operator.BOOL_OR) {
            auto p = n.parent.as!Binary;
            if(p && p.op==Operator.BOOL_AND) {
                module_.addError(n, "Parenthesis required to disambiguate these expressions", true);
            }
        }

        /// We need the types before we can continue
        if(lt.isUnknown || rt.isUnknown) {
            return;
        }

        if(lt.isNamedStruct) {
            if(n.op.isOverloadable || n.op.isComparison) {
                n.rewriteToOperatorOverloadCall();
                rewrites++;
                return;
            }
        }

        /// Rewrite anonstruct == anonstruct --> is_expr
        /// [int] a = [1]
        /// a == [1,2,3]
        if(n.op==Operator.BOOL_EQ && lt.isAnonStruct && rt.isAnonStruct) {
            if(lt.isValue && rt.isValue) {

                auto isExpr = makeNode!Is(n);
                isExpr.add(n.left);
                isExpr.add(n.right);

                fold(n, isExpr);
                return;
            }
        }

        if(n.type.isUnknown) {

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
        /// If left and right expressions are const numbers then evaluate them now
        /// and replace the Binary with the result
        if(n.isResolved && n.isConst) {

            // todo - make this work
            if(n.op.isAssign) return;

            auto leftLit  = n.left().as!LiteralNumber;
            auto rightLit = n.right().as!LiteralNumber;
            if(leftLit && rightLit) {

                auto lit = leftLit.copy();

                lit.value.applyBinary(n.type, n.op, rightLit.value);
                lit.str = lit.value.getString();

                fold(n, lit);
                return ;
            }
        }
    }
    void visit(Break n) {
        if(!n.isResolved) {
            n.loop = n.getAncestor!Loop;
            if(n.loop is null) {
                module_.addError(n, "Break statement must be inside a loop", true);
            }
        }
    }
    void visit(Call n) {
        if(!n.target.isResolved) {
            bool isTemplated = n.isTemplated;
            Expression prev  = n.prevLink();

            if(n.isStartOfChain()) {
                auto callable = callResolver.standardFind(n);
                if(callable.resultReady) {
                    /// If we get here then we have 1 good match
                    if(callable.isFunction) {
                        n.target.set(callable.func);
                    }
                    if(callable.isVariable) {
                        n.target.set(callable.var);
                    }
                }

            } else if(prev.id==NodeID.MODULE_ALIAS) {
                ///
                auto modAlias = prev.as!ModuleAlias;

                auto callable = callResolver.standardFind(n, modAlias);
                if(callable.resultReady) {
                    /// If we get here then we have 1 good match
                    assert(callable.isFunction);
                    n.target.set(callable.func);
                }
            } else {
                assert(prev);
                Type prevType = prev.getType;
                assert(prevType);

                if(!prevType.isKnown) return;

                auto dot = n.parent.as!Dot;
                assert(dot);

                if(!prevType.isNamedStruct) {
                    module_.addError(prev, "Left of call '%s' must be a struct type not a %s".format(n.name, prevType), true);
                    return;
                }

                //dd("module:", module_.canonicalName, "call:", n, "prevType:", prevType);

                NamedStruct ns = prevType.getNamedStruct;
                assert(ns);

                if(dot.isStaticAccess) {
                    auto callable = callResolver.structFind(n, ns, true);
                    if(callable.resultReady) {
                        /// If we get here then we have 1 good match
                        if(callable.isFunction) {
                            n.target.set(callable.func);
                        }
                        if(callable.isVariable) {
                            n.target.set(callable.var);
                        }
                    }
                } else {
                    if(n.name!="new" && !n.implicitThisArgAdded) {
                        /// Rewrite this call so that prev becomes the 1st argument (thisptr)

                        auto dummy = TypeExpr.make(prevType);

                        fold(prev, dummy);
                        //dot.replaceChild(prev, dummy);

                        if(prevType.isValue) {
                            auto ptr = makeNode!AddressOf;
                            ptr.add(prev);
                            n.insertAt(0, ptr);
                        } else {
                            n.insertAt(0, prev);
                        }

                        if(n.paramNames.length>0) n.paramNames ~= "this";

                        n.implicitThisArgAdded = true;
                        //rewrites++;
                    }

                    auto callable = callResolver.structFind(n, ns);

                    if(callable.resultReady) {
                        /// If we get here then we have 1 good match

                        if(callable.isFunction) {
                            n.target.set(callable.func, ns.getMemberIndex(callable.func));
                        }
                        if(callable.isVariable) {
                            n.target.set(callable.var, ns.getMemberIndex(callable.var));
                        }
                    }
                }
            }

            /// We added template params
            if(isTemplated != n.isTemplated) {
                rewrites++;
            }
        }

        if(n.target.isResolved && n.argTypes.areKnown) {
            /// We have a target and all args are known

            /// Check to see whether we need to add an implicit "this." prefix
            if(n.isStartOfChain() &&
               n.argTypes.length == n.target.paramTypes.length.as!int-1 &&
               !n.implicitThisArgAdded)
            {
                auto ns = n.getAncestor!NamedStruct;
                if(ns) {
                    auto r = identifierResolver.find("this", n);
                    if(r.found) {
                        n.addImplicitThisArg(r.var);
                        rewrites++;
                    }
                }
            }

            /// Rearrange the args to match the parameter order
            if(n.paramNames.length>0) {

                //dd("!!!", n.target, n.paramNames, n.target.paramNames());

                if(n.paramNames.length != n.target.paramNames().length) {
                    module_.addError(n, "Expecting %s arguments, not %s".format(n.target.paramNames().length, n.paramNames.length), true);
                    return;
                }

                import common : indexOf;
                auto targetNames = n.target.paramNames();
                auto args        = new Expression[n.numArgs];

                foreach(int i, name; n.paramNames) {
                    auto index = targetNames.indexOf(name);
                    if(index==-1) {
                        module_.addError(n, "Parameter name %s not found".format(name), true);
                        return;
                    }
                    args[index] = n.arg(i);
                }
                assert(args.length==n.numArgs);

                foreach(a; args) {
                    a.detach();
                }
                foreach(a; args) {
                    n.add(a);
                }

                /// We don't need the param names any more
                n.paramNames = null;
            } else {
                if(n.numArgs != n.target.paramTypes.length) {
                    module_.addError(n, "Expecting %s arguments, not %s".format(n.target.paramTypes.length, n.numArgs), true);
                }
            }

            if(!n.argTypes.canImplicitlyCastTo(n.target.paramTypes)) {
                module_.addError(n, "Cannot implicitly cast arguments (%s) to params (%s)".format(n.argTypes.toString, n.target.paramTypes.toString), true);
            }
        }
    }
    void visit(Calloc n) {
        resolveAlias(n, n.valueType);
    }
    void visit(Case n) {

    }
    void visit(Closure n) {

    }
    void visit(Composite n) {
        final switch(n.usage) with(Composite.Usage) {
            case STANDARD:
                /// Can be removed if empty
                /// Can be replaced if contains single child
                if(n.numChildren==0) {
                    n.detach();
                    rewrites++;
                } else if(n.numChildren==1) {
                    auto child = n.first();
                    fold(n, child);
                }
                break;
            case PERMANENT:
                /// Never remove or replace
                break;
            case PLACEHOLDER:
                /// Never remove
                /// Can be replaced if contains single child
                if(n.numChildren==1) {
                    auto child = n.first();
                    fold(n, child);
                }
                break;
        }
    }
    void visit(Continue n) {
        if(!n.isResolved) {
            n.loop = n.getAncestor!Loop;
            if(n.loop is null) {
                module_.addError(n, "Continue statement must be inside a loop", true);
            }
        }
    }
    void visit(Constructor n) {
        resolveAlias(n, n.type);
    }
    void visit(Alias n) {
        resolveAlias(n, n.type);
    }
    void visit(Dot n) {
        //n.resolve();
    }
    void visit(Function n) {

    }
    void visit(FunctionType n) {

    }
    void visit(Identifier n) {

        void findLocalOrGlobal() {
            auto res = identifierResolver.find(n.name, n);
            if(!res.found) {
                /// Ok to continue
                module_.addError(n, "identifier '%s' not found".format(n.name), true);
                return;
            }

            if(res.isFunc) {
                auto func = res.func;

                module_.buildState.functionRequired(func.moduleName, func.name);

                if(func.isStructMember) {
                    auto ns = n.getAncestor!NamedStruct();
                    assert(ns);

                    n.target.set(func, ns.getMemberIndex(func));
                } else {
                    /// Global, local or parameter
                    n.target.set(func);
                }
            } else {
                Variable var = res.isVar ? res.var : null;

                if(var.isStructMember) {
                    auto struct_ = n.getAncestor!AnonStruct();
                    assert(struct_);

                    n.target.set(var, struct_.getMemberIndex(var));
                } else {
                    /// Global, local or parameter
                    n.target.set(var);
                }

                /// If var is unknown we need to do some detective work...
                if(var.type.isUnknown && n.parent.isA!Binary) {
                    auto bin = n.parent.as!Binary;
                    if (bin.op == Operator.ASSIGN) {
                        auto opposite = bin.otherSide(n);
                        if (opposite && opposite.getType.isKnown) {
                            var.setType(opposite.getType);
                        }
                    }
                }
            }
        }
        void findStructMember() {
            Expression prev = n.prevLink();
            Type prevType   = prev.getType;

            if(!prevType.isKnown) return;

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
                        rewrites++;
                        return;
                    } else if(prevType.isAnonStruct) {
                        int len = prevType.getAnonStruct.numMemberVariables();
                        dot.parent.replaceChild(dot, LiteralNumber.makeConst(len, TYPE_INT));
                        rewrites++;
                        return;
                    }
                    break;
                case "subtype":
                    if(prevType.isArray) {
                        dot.parent.replaceChild(dot, TypeExpr.make(prevType.getArrayType.subtype));
                        rewrites++;
                        return;
                    }
                    break;
                case "ptr": {
                    if(!dot.isMemberAccess()) break;

                    auto b = module_.builder(n);
                    As as;
                    if(prevType.isArray) {
                        as = b.as(b.addressOf(prev), PtrType.of(prevType.getArrayType.subtype, 1));
                    } else if(prevType.isAnonStruct) {
                        as = b.as(b.addressOf(prev), PtrType.of(prevType.getAnonStruct, 1));
                    } else {
                        break;
                    }
                    if(prevType.isPtr) {
                        assert(false, "array is a pointer. handle this %s %s %s".format(prevType, module_.canonicalName, n.line));
                    }
                    /// As
                    ///   AddressOf
                    ///      prev
                    ///   type*
                    dot.parent.replaceChild(dot, as);
                    rewrites++;
                    return;
                }
                case "#size": {
                    int size = prevType.size();
                    dot.parent.replaceChild(dot, LiteralNumber.makeConst(size, TYPE_INT));
                    rewrites++;
                    return;
                }
                default:
                    break;
            }

            if(!prevType.isNamedStruct && !prevType.isAnonStruct) {
                module_.addError(prev, "Left of identifier %s must be a struct type not a %s (prev=%s)".format(n.name, prevType, prev), true);
                return;
            }

            AnonStruct struct_ = prevType.getAnonStruct();
            assert(struct_);
            NamedStruct ns = prevType.getNamedStruct;

            if(dot.isStaticAccess) {
                assert(ns);

                auto var = ns.getStaticVariable(n.name);
                if(var) {
                    if(var.access.isPrivate && var.getModule.nid != module_.nid) {
                        module_.addError(n, "%s is external and private".format(var.name), true);
                    }
                    n.target.set(var);
                }
            } else {
                auto var = struct_.getMemberVariable(n.name);
                if (var) {
                    n.target.set(var, struct_.getMemberIndex(var));
                } else {
                    /// If this is a static var then show a nice error
                    //auto ns = struct_.as!NamedStruct;
                    //if(ns && (var = ns.getStaticVariable(n.name))!is null) {
                    //    module_.addError(prev, "struct %s does not have member %s. Did you mean %s::%s ?"
                    //        .format(ns.name, n.name, ns.name, n.name));
                    //}
                }
            }
        }

        if(!n.target.isResolved) {
            if(n.isStartOfChain()) {
                findLocalOrGlobal();
            } else {
                findStructMember();
            }
        }

        /// If Identifier target is a const value then just replace with that value
        if(n.isResolved && n.isConst) {
            auto type = n.target.getType;
            auto var  = n.target.getVariable;

            if(type.isValue && (type.isInteger || type.isReal || type.isBool)) {
                assert(var.hasInitialiser);

                Initialiser ini = var.initialiser();
                auto lit        = ini.literal();

                if(lit && lit.isResolved) {
                    fold(n, lit.copy());
                    n.target.dereference();
                    return;
                }
            }
        }
    }
    void visit(If n) {
        if(!n.isResolved) {
            if(!n.isExpr) {
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
                    module_.addError(n, "If result types %s and %s are incompatible".format(thenType, elseType), true);
                }

                n.type = t;

            } else {
                n.type = thenType;
            }
        }
    }
    void visit(Import n) {

    }
    void visit(Index n) {

        if(n.exprType().isNamedStruct) {
            /// Rewrite this to a call to operator[]

            auto ns = n.exprType.getNamedStruct;

            auto struct_ = n.exprType.getAnonStruct;
            assert(struct_);

            auto b = module_.builder(n);

            if(n.parent.isBinary) {
                auto bin = n.parent.as!Binary;
                if(bin.op.isAssign && n.nid==bin.left.nid) {
                    /// Rewrite to operator:(int,value)

                    /// Binary =
                    ///     Index
                    ///         index
                    ///         struct
                    ///     expr
                    ///....................
                    /// Dot
                    ///     [AddressOf] struct
                    ///     Call
                    ///         index
                    ///         expr
                    auto left = n.exprType.isValue ? b.addressOf(n.expr) : n.expr;
                    auto call = b.call("operator[]", null)
                                 .add(n.index)
                                 .add(bin.right);

                    auto dot = b.dot(left, call);

                    bin.parent.replaceChild(bin, dot);

                    rewrites++;
                    return;
                }
            }
            /// Rewrite to operator:(int)

            /// Index
            ///     struct
            ///     index
            ///.............
            /// Dot
            ///     [AddressOf] struct
            ///     Call
            ///         index
            auto left = n.exprType.isValue ? b.addressOf(n.expr) : n.expr;
            auto call = b.call("operator[]", null)
                         .add(n.index);

            auto dot = b.dot(left, call);

            fold(n, dot);

            //n.parent.replaceChild(n, dot);
            //rewrites++;
            return;

        }
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

                    if(parentType.isArray && parentType.getArrayType.numChildren==0) {
                        dd("!!booo");
                    }

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
                        module_.addError(n, "Cannot cast array literal to %s".format(type), true);
                        return;
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
                //auto arrayStruct = n.parent.getType().getArrayStruct;
                //assert(arrayStruct, "Expecting ArrayStruct, got %s".format(n.parent.getType()));

                //n.type.subtype = arrayStruct.subtype;
            }
        }
        //if(n.type.isKnown) {
        //    if(n.isArray) {
        //        /// Check that element type matches
        //
        //        auto eleType = n.type.getArrayStruct.subtype;
        //        //auto t       = n.calculateElementType(eleType);
        //
        //        foreach(i, t; n.elementTypes()) {
        //            if(!t.canImplicitlyCastTo(eleType)) {
        //                module_.addError(n.children[i],
        //                    "Expecting an array of %s. Cannot implicitly cast %s to %s".format(eleType, t, eleType));
        //                return;
        //            }
        //        }
        //
        //    } else {
        //
        //    }
        //}
    }
    void visit(LiteralExpressionList n) {
        /// Try to convert this into either a LiteralStruct or a LiteralArray
        n.resolve();
        rewrites++;
    }
    void visit(LiteralFunction n) {
        if(n.type.isUnknown) {

            auto ty = n.type.getFunctionType;
            if(ty.returnType.isUnknown) {
                ty.returnType = n.determineReturnType();
            }
        }
    }
    void visit(LiteralMap n) {
        assert(false, "implement visit.LiteralMap");
    }
    void visit(LiteralNull n) {
        if(n.type.isUnknown) {
            //if(module_.canonicalName=="test_select") dd("!! null", n.parent.id);
            auto parent = n.parent;
            if(parent.isComposite) parent = parent.parent;

            Type type;
            /// Determine type from parent
            switch(parent.id()) with(NodeID) {
                case AS:
                    type = parent.as!As.getType;
                    break;
                case BINARY:
                    type = parent.as!Binary.leftType();
                    break;
                case CASE:
                    type = parent.as!Case.getSelectType();
                    break;
                case IF:
                    auto if_ = parent.as!If;
                    if(if_.hasThen && if_.hasElse) {
                        if(n.nid==if_.thenStmt().nid) {
                            type = if_.elseType();
                        } else {
                            type = if_.thenType();
                        }
                    }
                    break;
                case INITIALISER:
                    type = parent.as!Initialiser.getType;
                    break;
                case IS:
                    type = parent.as!Is.oppositeSideType(n);
                    break;
                case VARIABLE:
                    type = parent.as!Variable.type;
                    break;
                default:
                    assert(false, "parent is %s".format(parent.id()));
            }

            if(type && type.isKnown) {
                if(type.isPtr) {
                    n.type = type;
                } else {
                    module_.addError(n, "Cannot implicitly cast null to %s".format(type), true);
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
            resolveAlias(n, n.type);
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
                    } else {
                        type = n.getInferredType();
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
                case RETURN: {
                    auto ret = n.parent.as!Return;
                    auto lf  = ret.getLiteralFunction();
                    if(lf.getType.isKnown) {
                        type = lf.getType.getFunctionType.returnType;
                    }
                    break;
                }
                case VARIABLE:
                    type = n.parent.as!Variable.type;
                    break;
                default:
                    assert(false, "Parent of LiteralStruct is %s".format(n.parent.id));
            }
            if(type && type.isKnown) {
                if(!type.isAnonStruct) {
                    module_.addError(n, "Cannot cast struct literal to %s".format(type), true);
                    return;
                }
                n.type = type;
            }
        }
    }
    void visit(Loop n) {

    }
    void visit(Module n) {

    }
    void visit(ModuleAlias n) {

    }
    void visit(NamedStruct n) {

    }
    void visit(Parameters n) {

    }
    void visit(Parenthesis n) {
        assert(n.numChildren==1);

        /// We don't need any Parentheses any more
        fold(n, n.expr());
    }
    void visit(Return n) {

    }
    void visit(Select n) {
        if(!n.isResolved) {

            Type[] types = n.casesIncludingDefault().map!(it=>it.getType).array;

            //Type[] types = n.casesIncludingDefault()
            //                .filter!(it=>
            //                    it.isResolvable()
            //                )
            //                .map!(it=>it.getType)
            //                .array;

            //foreach(c; n.cases()) {
            //    auto t = c.getType;
            //
            //    if(t.isKnown) {
            //        types ~= t;
            //    } else {
            //        /// Handle literal null
            //        if(c.stmts().first.isLiteralNull) {
            //            /// ignore this one
            //        } else {
            //            /// We can't continue
            //            return;
            //        }
            //    }
            //}
            if(!types.areKnown) return;

            auto type = getBestFit(types);
            if(type) {
                n.type = type;
            }
        }
        if(n.isResolved && !n.isSwitch) {
            ///
            /// Convert to a series of if/else
            ///
            auto cases = n.cases();
            auto def   = n.defaultStmts();

            /// Exit if this select is badly formed. This will already be an error
            if(cases.length==0 || def is null) return;

            If first;
            If prev;

            foreach(c; n.cases()) {
                If if_ = makeNode!If(n);
                if(first is null) first = if_;

                if(prev) {
                    /// else
                    auto else_ = Composite.make(n, Composite.Usage.PERMANENT);
                    else_.add(if_);
                    prev.add(else_);
                }

                /// No inits
                if_.add(Composite.make(n, Composite.Usage.PERMANENT));

                /// Condition
                if_.add(c.cond());

                /// then
                if_.add(c.stmts());

                prev = if_;
            }
            /// Final else
            assert(first);
            assert(prev);
            prev.add(def);

            fold(n, first);
            return;
        }
    }
    void visit(TypeExpr n) {
        resolveAlias(n, n.type);
    }
    void visit(Unary n) {

        if(n.expr.getType.isNamedStruct && n.op.isOverloadable) {
            /// Look for an operator overload
            string name = "operator" ~ n.op.value;

            auto struct_ = n.expr.getType.getAnonStruct;
            assert(struct_);

            /// Rewrite to operator overload:
            /// Unary
            ///     expr struct
            /// Dot
            ///     AddressOf
            ///         expr struct
            ///     Call
            ///
            auto b = module_.builder(n);

            auto left  = n.expr.getType.isValue ? b.addressOf(n.expr) : n.expr;
            auto right = b.call(name, null);

            auto dot = b.dot(left, right);

            fold(n, dot);
            return;
        }
        /// If expression is a const literal number then apply the
        /// operator and replace Unary with the result
        if(n.isResolved && n.isConst) {
            auto lit = n.expr().as!LiteralNumber;
            if(lit) {
                lit.value.applyUnary(n.op);
                lit.str = lit.value.getString();

                fold(n, lit);
                return;
            }
        }
    }
    void visit(ValueOf n) {
        if(n.expr.id==NodeID.ADDRESS_OF) {
            auto addrof = n.expr.as!AddressOf;
            auto child  = addrof.expr;
            fold(n, child);
            return;
        }
    }
    void visit(Variable n) {

        resolveAlias(n, n.type);

        if(n.type.isUnknown) {

            if(n.isParameter) {
                /// If we are a closure inside a call
                auto call = n.getAncestor!Call;
                if(call && call.isResolved) {

                    auto params = n.parent.as!Parameters;
                    assert(params);

                    auto callIndex = call.indexOf(n);

                    auto ptype = call.target.paramTypes[callIndex];
                    if(ptype.isFunction) {
                        auto idx = params.getIndex(n);
                        assert(idx!=-1);

                        if(idx<ptype.getFunctionType.paramTypes.length) {
                            auto t = ptype.getFunctionType.paramTypes[idx];
                            n.setType(t);
                        }
                    }
                }
            }

            if(n.hasInitialiser) {
                /// Get the type from the initialiser
                if(n.initialiserType().isKnown) {
                    n.setType(n.initialiserType());
                }
            } else {
                /// No initialiser

            }

            //if(n.isGlobal() || n.isStructMember()) {
            //    dd(n.name, n.type);
            //
            //    module_.addError(n, "Globals or struct member variables must have explicit type");
            //}
        }
        if(n.type.isKnown) {
            /// Ensure the function ptr matches the closure type
            if(n.isFunctionPtr && n.hasInitialiser) {
                auto lf = n.getDescendent!LiteralFunction;
                if(lf) {
                    lf.type = n.type;
                }
            }
        }
    }
    //==========================================================================
    void writeAST() {
        if(!module_.config.writeAST) return;

        //dd("DUMP MODULE", module_);

        auto f = new FileLogger(module_.config.targetPath~"ast/" ~ module_.fileName~".ast");
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

        if(!isAttached(m)) return;

        if(m.id==NodeID.NAMED_STRUCT) {
            if(m.as!NamedStruct.isTemplateBlueprint) return;
        } else if(m.isFunction) {
            auto f = m.as!Function;
            if(f.isTemplateBlueprint) return;
            if(f.isImport) return;
        } else if(m.isAlias) {
            auto d = m.as!Alias;
            if(!d.type.isAlias) return;
        }

        //dd("  resolve", typeid(m), "nid:", m.nid, module_.canonicalName, "line:", m.line+1);
        /// Resolve this node
        m.visit!ModuleResolver(this);

        if(!isAttached(m)) return;

        if(!m.isResolved) {
            unresolved.add(m);
        }

        /// Visit children
        foreach(n; m.children[].dup) {
            recursiveVisit(n);
        }
    }
    bool isAttached(ASTNode n) {
        if(n.parent is null) return false;
        if(n.parent.isModule) return true;
        return isAttached(n.parent);
    }
    void fold(ASTNode replaceMe, ASTNode withMe) {
        auto p = replaceMe.parent;
        p.replaceChild(replaceMe, withMe);
        rewrites++;

        //if(module_.canonicalName=="test_statics") {
        //    dd("=======> folded", replaceMe.line, replaceMe, "child=", replaceMe.hasChildren ? replaceMe.first : null);
        //    dd("withMe=", withMe);
        //}
        /// Ensure active roots remain valid
        module_.addActiveRoot(withMe);
    }
    ///
    /// If this is the first time we have looked at this module then add           
    /// all module level variables to the list of roots to resolve
    ///
    void collectModuleScopeElements() {
        if(!addedModuleScopeElements && module_.isParsed) {
            addedModuleScopeElements = true;

            foreach(n; module_.getVariables()) {
                module_.addActiveRoot(n);
            }
        }
    }
    ///
    /// If type is a Alias then we need to resolve it
    ///
    void resolveAlias(ASTNode node, ref Type type) {
        if(!type.isAlias) return;

        auto def = type.getAlias;

        /// Handle import
        if(def.isImport) {
            auto m = module_.buildState.getOrCreateModule(def.moduleName);
            if(m.isParsed) {
                auto externDef = m.getAlias(def.name);
                if(externDef) {
                    /// Switch to the external Alias
                    def  = externDef;
                    type = PtrType.of(externDef, type.getPtrDepth);
                } else {
                    auto ns = m.getNamedStruct(def.name);
                    if(ns) {
                        /// Alias is resolved
                        type = PtrType.of(ns, type.getPtrDepth);
                        return;
                    }
                    module_.addError(module_, "Import %s not found in module %s".format(def.name, def.moduleName), true);
                    return;
                }
            } else {
                /// Come back when m is parsed
                return;
            }
        }

        /// Handle template proxy Alias
        if(def.isTemplateProxy) {

            /// Ensure template params are resolved
            foreach(ref t; def.templateProxyParams) {
                resolveAlias(node, t);
            }

            /// Resolve until we have the NamedStruct
            if(def.templateProxyType.isAlias) {
                resolveAlias(node, def.templateProxyType);
            }
            if(!def.templateProxyType.isNamedStruct) {
                typesWaiting++;
                return;
            }

            /// We now have a NamedStruct to work with
            if(def.templateProxyParams.areKnown) {
                auto ns            = def.templateProxyType.getNamedStruct;
                string mangledName = ns.getUniqueName ~ "<" ~ module_.buildState.mangler.mangle(def.templateProxyParams) ~ ">";

                auto t = module_.typeFinder.findType(mangledName, ns);
                if(t) {
                    assert(t.isNamedStruct);
                    type = PtrType.of(t, type.getPtrDepth);
                    t.getNamedStruct.numRefs++;
                } else {
                    /// Extract the template
                    auto structModule = module_.buildState.getOrCreateModule(ns.moduleName);
                    structModule.templates.extract(ns, node, mangledName, def.templateProxyParams);

                    typesWaiting++;
                }
            }
            return;
        }

        if(def.type.isKnown || def.type.isAlias) {
            /// Switch to the Aliasd type
            type = PtrType.of(def.type, type.getPtrDepth);
        } else {
            typesWaiting++;
        }
    }
}