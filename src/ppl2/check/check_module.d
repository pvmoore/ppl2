module ppl2.check.check_module;

import ppl2.internal;
///
/// Check semantics after all types have been resolved.
///
final class ModuleChecker {
private:
    Module module_;
    StopWatch watch;
    Set!string stringSet;
    IdentifierResolver identifierResolver;
    EscapeAnalysis escapeAnalysis;
public:
    this(Module module_) {
        this.module_            = module_;
        this.stringSet          = new Set!string;
        this.identifierResolver = new IdentifierResolver(module_);
        this.escapeAnalysis     = new EscapeAnalysis(module_);
    }
    void clearState() {
        watch.reset();
    }

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    void check() {
        watch.start();

        recursiveVisit(module_);

        checkAttributes();

        watch.stop();
    }
    //==========================================================================
    void visit(AddressOf n) {

    }
    void visit(Alias n) {

    }
    void visit(Array n) {
        if(!n.countExpr().isA!LiteralNumber) {
            module_.addError(n.countExpr(), "Array count expression must be a const", true);
        }
    }
    void visit(As n) {
        Type fromType = n.leftType;
        Type toType   = n.rightType;

        if(fromType.isPtr && toType.isPtr) {
            /// ok - bitcast pointers
        } else if(fromType.isPtr && !toType.isInteger) {
            errorBadExplicitCast(module_, n, fromType, toType);
        } else if(!fromType.isInteger && toType.isPtr) {
            errorBadExplicitCast(module_, n, fromType, toType);
        }
    }
    void visit(Binary n) {

        assert(n.numChildren==2, "Binary numChildren=%s. Expecting 2".format(n.numChildren));

        if(n.left.isTypeExpr) {
            module_.addError(n.left, "Expecting an expression here not a type", true);
        }
        if(n.right.isTypeExpr) {
            module_.addError(n.right, "Expecting an expression here not a type", true);
        }

        /// Check the types
        if(n.isPtrArithmetic) {

        } else {
            if(!areCompatible(n.rightType, n.leftType)) {
                module_.addError(n, "Types are incompatible: %s and %s".format(n.leftType, n.rightType), true);
            }
        }

        if(n.op.isAssign) {

            if(n.op!=Operator.ASSIGN && n.leftType.isPtr && n.rightType.isInteger) {
                /// int* a = 10
                /// a += 10
            } else if(!n.rightType.canImplicitlyCastTo(n.leftType)) {
                errorBadImplicitCast(module_, n, n.rightType, n.leftType);
            }

            /// Check whether we are modifying a const variable
            if(!n.parent.isInitialiser) {
                auto id = n.left().as!Identifier;
                if(id && id.target.isVariable && id.target.getVariable.isConst) {
                    module_.addError(n, "Cannot modify const %s".format(id.name), true);
                }
            }
        } else {

        }
    }
    void visit(Break n) {

    }
    void visit(Call n) {
        auto paramTypes = n.target.paramTypes();
        auto argTypes   = n.argTypes();

        /// Ensure we have the correct number of arguments
        if(paramTypes.length != argTypes.length) {
            module_.addError(n, "Expecting %s arguments, not %s".format(paramTypes.length, argTypes.length), true);
        }

        /// Ensure the arguments can implicitly cast to the parameters
        foreach(int i, p; n.target.paramTypes()) {
            if(!argTypes[i].canImplicitlyCastTo(p)) {
                errorBadImplicitCast(module_, n.arg(i), argTypes[i], p);
            }
        }
    }
    void visit(Calloc n) {

    }
    void visit(Case n) {

    }
    void visit(Closure n) {

    }
    void visit(Composite n) {

    }
    void visit(Constructor n) {

    }
    void visit(Continue n) {

    }
    void visit(Dot n) {

    }
    void visit(Enum n) {

    }
    void visit(EnumMember n) {
        /// Must be convertable to element type
        // todo - should have been removed
    }
    void visit(EnumMemberValue n) {

    }
    void visit(ExpressionRef n) {

    }
    void visit(Function n) {

        auto retType = n.getType.getFunctionType.returnType;

        switch(n.name) {
            case "operator<>":
                if(retType.isPtr || !retType.isInt) {
                    module_.addError(n, "operator<> must return int", true);
                }
                break;
            case "operator:":
                if(n.params.numParams==2) {
                    /// get
                    if(retType.isValue && retType.isVoid) {
                        module_.addError(n, "operator:(this,int) must not return void", true);
                    }
                } else if(n.params.numParams==3) {
                    /// set

                }
                break;
            default:
                break;
        }
    }
    void visit(FunctionType n) {

    }
    void visit(Identifier n) {

        void checkReadOnlyAssignment(Access access, string moduleName) {
        //    // allow writing to indexed pointer value
        //    auto idx = findAncestor!Index;
        //    if(idx) return;
        //
            if(access.isReadOnly && moduleName!=module_.canonicalName) {
                auto a = n.getAncestor!Binary;
                if(a && a.op.isAssign && n.isAncestor(a.left)) {
                    module_.addError(n, "Property is readonly", true);
                }
            }
        }

        void checkPrivateAccess(Access access, string moduleName) {
            if(access.isPrivate && moduleName!=module_.canonicalName) {
                module_.addError(n, "Property is private", true);
            }
        }


        if(n.target.isMemberVariable) {
            auto var = n.target.getVariable;
            checkPrivateAccess(var.access, var.getModule.canonicalName);
            checkReadOnlyAssignment(var.access, var.getModule.canonicalName);
        }
        if(n.target.isMemberFunction) {
            auto func = n.target.getFunction;
            checkPrivateAccess(func.access, func.moduleName);
            checkReadOnlyAssignment(func.access, func.moduleName);
        }
    }
    void visit(If n) {
        if(n.isExpr) {
            /// Type must not be void
            if(n.type.isVoid && n.type.isValue) {
                module_.addError(n, "If must not have void result", true);
            }

            /// Both then and else are required
            if(!n.hasThen || !n.hasElse) {
                module_.addError(n, "If must have both a then and an else result", true);
            }

            /// Don't allow any returns in then or else block
            auto array = new DynamicArray!Return;
            n.selectDescendents!Return(array);
            if(array.length>0) {
                module_.addError(array[0], "An if used as a result cannot return", true);
            }
        }
    }
    void visit(Import n) {

    }
    void visit(Index n) {
        auto lit = n.index().as!LiteralNumber;
        if(lit) {
            /// Index is a const. Check the bounds
            if(n.isArrayIndex) {
                Array array = n.exprType().getArrayType;
                assert(array);

                auto count = array.countExpr().as!LiteralNumber;
                assert(count);

                if(lit.value.getInt() >= count.value.getInt()) {
                    module_.addError(n, "Array bounds error. %s >= %s".format(lit.value.getInt(), count.value.getInt()), true);
                }
            } else if(n.isTupleIndex) {

                Tuple tuple = n.exprType().getTuple;
                assert(tuple);

                auto count = tuple.numMemberVariables();
                assert(count);

                if(lit.value.getInt() >= count) {
                    module_.addError(n, "Array bounds error. %s >= %s".format(lit.value.getInt(), count), true);
                }
            } else {
                /// ptr

            }
        } else {
            if(n.isTupleIndex) {
                module_.addError(n, "Tuple index must be a const number", true);
            }

            /// We could add a runtime check here in debug mode
        }
        if(n.exprType.isKnown) {

        }
    }
    void visit(Initialiser n) {

    }
    void visit(Is n) {

    }
    void visit(LiteralArray n) {
        /// Check for too many values
        if(n.length() > n.type.countAsInt()) {
            module_.addError(n, "Too many values specified (%s > %s)".format(n.length(), n.type.countAsInt()), true);
        }

        foreach(i, left; n.elementTypes()) {

            if(!left.canImplicitlyCastTo(n.type.subtype)) {
                errorBadImplicitCast(module_, n.elementValues()[i], left, n.type.subtype);
            }
        }
    }
    void visit(LiteralFunction n) {
        assert(n.first().isA!Parameters);

        /// Check for duplicate Variable names
        Variable[string] map;

        n.recurse!Variable((v) {
            if(v.name) {
                auto ptr = v.name in map;
                if(ptr) {
                    auto v2 = *ptr;

                    bool sameScope = v.parent is v2.parent;

                    if(sameScope) {
                        module_.addError(v, "Variable '%s' is declared more than once in this scope (Previous declaration is on line %s)"
                            .format(v.name, v2.line+1), true);
                    } else if(v.isLocalAlloc) {
                        /// Check for shadowing
                        auto res = identifierResolver.find(v.name, v.previous());
                        if(res.found) {
                            module_.addError(v, "Variable '%s' is shadowing another variable declared on line %s".format(v.name, res.line+1), true);
                        }
                    }
                }
                map[v.name] = v;
            }
        });

        escapeAnalysis.analyse(n);
    }
    void visit(LiteralMap n) {

    }
    void visit(LiteralNull n) {

    }
    void visit(LiteralNumber n) {
        Type* ptr;

        switch(n.parent.id()) with(NodeID) {
            case VARIABLE:
                ptr = &n.parent.as!Variable.type;
                break;
            default: break;
        }

        if(ptr) {
            auto parentType = *ptr;

            if(!n.type.canImplicitlyCastTo(parentType)) {
                errorBadImplicitCast(module_, n, n.type, parentType);
            }
        }
    }
    void visit(LiteralString n) {

    }
    void visit(LiteralTuple n) {
        Tuple tuple = n.type.getTuple;
        assert(tuple);

        auto structTypes = tuple.memberVariableTypes();

        /// Check for too many values
        if(n.numElements > tuple.numMemberVariables) {
            module_.addError(n, "Too many values specified", true);
        }

        if(n.numElements==0) {

        }
        if(n.names.length > 0) {
            /// This uses name=value to initialise elements

            /// Check that the names are valid and are not repeated
            stringSet.clear();
            foreach(i, name; n.names) {
                if(stringSet.contains(name)) {
                    module_.addError(n.children[i], "Tuple member %s initialised more than once".format(name), true);
                }
                stringSet.add(name);
                auto v = tuple.getMemberVariable(name);
                if(!v) {
                    module_.addError(n.children[i], "Tuple does not have member %s".format(name), true);
                }
            }

            auto elementTypes = n.elementTypes();

            foreach(i, name; n.names) {
                auto var   = tuple.getMemberVariable(name);

                auto left  = elementTypes[i];
                auto right = var.type;
                if(!left.canImplicitlyCastTo(right)) {
                    errorBadImplicitCast(module_, n.elements()[i], left, right);

                }
            }

        } else {
            /// This is a list of elements

            /// Check that the element types match the struct members
            foreach(i, t; n.elementTypes()) {
                auto left  = t;
                auto right = structTypes[i];
                if(!left.canImplicitlyCastTo(right)) {
                    errorBadImplicitCast(module_, n.elements()[i], left, right);
                }
            }
        }
    }
    void visit(Loop n ) {

    }
    void visit(Module n) {
        /// Ensure all global variables have a unique name
        stringSet.clear();
        foreach(v; module_.getVariables()) {
            if(stringSet.contains(v.name)) {
                module_.addError(v, "Global variable %s declared more than once".format(v.name), true);
            }
            stringSet.add(v.name);
        }
    }
    void visit(ModuleAlias n) {

    }
    void visit(Parameters n) {
        /// Check that all arg names are unique
        stringSet.clear();
        foreach(i, a; n.paramNames) {
            if(stringSet.contains(a)) {
                module_.addError(n.getParam(i), "Duplicate parameter name", true);
            }
            stringSet.add(a);
        }
    }
    void visit(Struct n) {

        stringSet.clear();
        foreach(v; n.getMemberVariables()) {
            /// Variables must have a name
            if(v.name.length==0) {
                module_.addError(v, "Struct variable must have a name", true);
            } else {
                /// Names must be unique
                if(stringSet.contains(v.name)) {
                    module_.addError(v, "Struct %s has duplicate member %s".format(n.name, v.name), true);
                }
                stringSet.add(v.name);
            }
        }
    }
    void visit(Parenthesis n) {

    }
    void visit(Return n) {

    }
    void visit(Select n) {
        assert(n.isSwitch);

        /// Check that each clause can be converted to the type of the switch value
        auto valueType = n.valueType();
        foreach(c; n.cases()) {
            foreach(expr; c.conds()) {
                if(!expr.getType.canImplicitlyCastTo(valueType)) {
                    errorBadImplicitCast(module_, expr, expr.getType, valueType);
                }
            }
        }
        /// Check that all clauses are const integers
        foreach(c; n.cases()) {
            foreach(expr; c.conds()) {
                auto lit = expr.as!LiteralNumber;
                if(!lit || (!lit.getType.isInteger && !lit.getType.isBool)) {
                    module_.addError(expr, "Switch-style Select clauses must be of const integer type", true);
                }
            }
        }
    }
    void visit(Tuple n) {
        stringSet.clear();
        foreach(v; n.getMemberVariables()) {
            /// Names must be unique
            if(v.name) {
                if(stringSet.contains(v.name)) {
                    module_.addError(v, "Tuple has duplicate member %s".format(v.name), true);
                }
                stringSet.add(v.name);
            }
        }
    }
    void visit(TypeExpr n) {

    }
    void visit(Unary n) {

    }
    void visit(ValueOf n) {

    }
    void visit(Variable n) {
        if(n.isConst) {

            if(!n.isGlobal && !n.isStructMember) {
                /// Initialiser must be const
                auto ini = n.initialiser();
                if(!ini.isConst) {
                    module_.addError(n, "Const initialiser must be const", true);
                }
            }
        }
        if(n.isStructMember) {

            auto s = n.getStruct;

            if(s.isPOD && !n.access.isPublic) {
                module_.addError(n, "POD struct member variables must be public", true);
            }
        }
        if(n.isStatic) {
            if(!n.parent.id==NodeID.STRUCT) {
                module_.addError(n, "Static variables are only allowed in a struct", true);
            }
        }
        if(n.type.isStruct) {

        }

        if(n.type.isTuple) {
            auto tuple = n.type.getTuple();

            /// Tuples must only contain variable declarations
            foreach(v; tuple.children) {
                if(!v.isVariable) {
                    module_.addError(n, "A tuple must only contain variable declarations", true);
                } else {
                    auto var = cast(Variable)v;
                    if(var.hasInitialiser) {
                        module_.addError(n, "A tuple must not have variable initialisation", true);
                    }
                }
            }
        }
        if(n.isParameter) {

        }
        if(n.isLocalAlloc) {

        }
    }
    //==========================================================================
private:
    void recursiveVisit(ASTNode m) {
        //dd("check", typeid(m));
        m.visit!ModuleChecker(this);
        foreach(n; m.children) {
            recursiveVisit(n);
        }
    }
    void checkAttributes() {

        void check(ASTNode node, Attribute a) {
            bool ok = true;
            final switch(a.type) with(Attribute.Type) {
                case EXPECT:
                    ok = node.isIf;
                    break;
                case INLINE:
                    ok = node.isFunction;
                    break;
                case LAZY:
                    ok = node.isFunction;
                    break;
                case MEMOIZE:
                    ok = node.isFunction;
                    break;
                case MODULE:
                    ok = node.isModule;
                    break;
                case NOTNULL:
                    break;
                case PACK:
                    ok = node.id==NodeID.STRUCT;
                    break;
                case POD:
                    ok = node.id==NodeID.STRUCT;
                    break;
                case PROFILE:
                    ok = node.isFunction;
                    break;
                case RANGE:
                    ok = node.isVariable;
                    break;
            }
            if(!ok) {
                module_.addError(node, "%s attribute cannot be applied to %s".
                    format(a.name, node.id.to!string.toLower), true);
            }
        }

        module_.recurse!ASTNode((n) {
            auto attribs = n.attributes;
            foreach(a; attribs) {
                check(n, a);
            }
        });
    }
}