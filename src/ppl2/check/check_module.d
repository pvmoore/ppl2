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
public:
    this(Module module_) {
        this.module_            = module_;
        this.stringSet          = new Set!string;
        this.identifierResolver = new IdentifierResolver(module_);
    }

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    void check() {
        watch.start();

        recursiveVisit(module_);

        watch.stop();
    }
    //==========================================================================
    void visit(AddressOf n) {

    }
    void visit(AnonStruct n) {

    }
    void visit(Parameters n) {
        /// Check that all arg names are unique
        stringSet.clear();
        foreach(i, a; n.paramNames) {
            if(stringSet.contains(a)) {
                throw new CompilerError(n.getParam(i), "Duplicate parameter name");
            }
            stringSet.add(a);
        }
    }

    void visit(ArrayType n) {
        if(!n.countExpr().isA!LiteralNumber) {
            errorArrayCountMustBeConst(n.countExpr());
        }
    }
    void visit(As n) {
        Type fromType = n.leftType;
        Type toType   = n.rightType;

        if(fromType.isPtr && toType.isPtr) {
            /// ok - bitcast pointers
        } else if(fromType.isPtr && !toType.isLong) {
            errorBadExplicitCast(n, fromType, toType);
        } else if(!fromType.isLong && toType.isPtr) {
            errorBadExplicitCast(n, fromType, toType);
        }
    }
    void visit(Binary n) {

        /// Check the types
        if(!areCompatible(n.rightType, n.leftType)) {
            errorIncompatibleTypes(n, n.rightType, n.leftType);
        }

        if(n.op.isAssign) {

            if(!n.rightType.canImplicitlyCastTo(n.leftType)) {
                errorBadImplicitCast(n, n.rightType, n.leftType);
            }

            /// Check whether we are modifying a const variable
            if(!n.parent.isInitialiser) {
                auto id = n.left().as!Identifier;
                if(id && id.target.isVariable && id.target.getVariable.isConst) {
                    errorModifyingConst(n, id);
                }
            }
        }
    }
    void visit(Break n) {

    }
    void visit(Call n) {
        auto paramTypes = n.target.paramTypes();
        auto argTypes   = n.argTypes();

        /// Ensure we have the correct number of arguments
        if(paramTypes.length != argTypes.length) {
            throw new CompilerError(n,
                "Expecting %s arguments, not %s".format(paramTypes.length, argTypes.length));
        }

        /// Ensure the arguments can implicitly cast to the parameters
        foreach(int i, p; n.target.paramTypes()) {
            if(!argTypes[i].canImplicitlyCastTo(p)) {
                errorBadImplicitCast(n.arg(i), argTypes[i], p);
            }
        }
    }
    void visit(Calloc n) {

    }
    void visit(Closure n) {

    }
    void visit(Composite n) {

    }
    void visit(Constructor n) {

    }
    void visit(Continue n) {

    }
    void visit(Alias n) {
        if(n.type.isAnonStruct) {

        }
    }
    void visit(Dot n) {

    }
    void visit(Function n) {

        auto retType = n.getType.getFunctionType.returnType;

        switch(n.name) {
            case "operator<>":
                if(retType.isPtr || !retType.isInt) {
                    throw new CompilerError(n,
                        "operator<> must return int");
                }
                break;
            case "operator:":
                if(n.params.numParams==2) {
                    /// get
                    if(retType.isValue && retType.isVoid) {
                        throw new CompilerError(n,
                            "operator:(this,int) must not return void");
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

        void checkReadOnlyAssignment(Access access, int moduleNID) {
        //    // allow writing to indexed pointer value
        //    auto idx = findAncestor!Index;
        //    if(idx) return;
        //
            if(access.isReadOnly && moduleNID!=module_.nid) {
                auto a = n.getAncestor!Binary;
                if(a && a.op.isAssign && n.isAncestor(a.left)) {
                    throw new CompilerError(n,
                        "Attempting to modify readonly property");
                }
            }
        }

        void checkPrivateAccess(Access access, int moduleNID) {
            if(access.isPrivate && moduleNID!=module_.nid) {
                throw new CompilerError( n,
                    "Attempting to access private property");
            }
        }


        if(n.target.isMemberVariable) {
            auto var = n.target.getVariable;
            checkPrivateAccess(var.access, var.moduleNID);
            checkReadOnlyAssignment(var.access, var.moduleNID);
        }
        if(n.target.isMemberFunction) {
            auto func = n.target.getFunction;
            checkPrivateAccess(func.access, func.moduleNID);
            checkReadOnlyAssignment(func.access, func.moduleNID);
        }
    }
    void visit(If n) {
        if(n.isExpr) {
            /// Type must not be void
            if(n.type.isVoid && n.type.isValue) {
                throw new CompilerError(n,
                    "If must not have void result");
            }

            /// Both then and else are required
            if(!n.hasThen || !n.hasElse) {
                throw new CompilerError(n,
                    "If must have both a then and an else result");
            }

            /// Don't allow any returns in then or else block
            auto array = new Array!Return;
            n.selectDescendents!Return(array);
            if(array.length>0) {
                throw new CompilerError(array[0],
                    "An if used as a result cannot return");
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
                ArrayType array = n.exprType().getArrayType;
                assert(array);

                auto count = array.countExpr().as!LiteralNumber;
                assert(count);

                if(lit.value.getInt() >= count.value.getInt()) {
                    errorArrayBounds(n, lit.value.getInt(), count.value.getInt());
                }
            } else if(n.isStructIndex) {

                AnonStruct struct_ = n.exprType().getAnonStruct;
                assert(struct_);

                auto count = struct_.numMemberVariables();
                assert(count);

                if(lit.value.getInt() >= count) {
                    errorArrayBounds(n, lit.value.getInt(), count);
                }
            } else {
                /// ptr

            }
        } else {
            if(n.isStructIndex) {
                throw new CompilerError(n,
                    "Struct index must be a const number");
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
            throw new CompilerError(n,
                "Too many values specified (%s > %s)".format(n.length(), n.type.countAsInt()));
        }

        if(n.isIndexBased) {

        } else {

            foreach(i, left; n.elementTypes()) {

                if(!left.canImplicitlyCastTo(n.type.subtype)) {
                    errorBadImplicitCast(n.elementValues()[i], left, n.type.subtype);
                }
            }
        }
    }
    void visit(LiteralFunction n) {
        assert(n.first().isA!Parameters);

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
                errorBadImplicitCast(n, n.type, parentType);
            }
        }
    }
    void visit(LiteralString n) {

    }
    void visit(LiteralStruct n) {
        AnonStruct struct_ = n.type.getAnonStruct;
        assert(struct_);

        auto structTypes = struct_.memberVariableTypes();

        /// Check for too many values
        if(n.numElements > struct_.numMemberVariables) {
            throw new CompilerError(n,
            "Too many values specified");
        }

        if(n.numElements==0) {

        }
        if(n.names.length > 0) {
            /// This uses name=value to initialise elements

            /// Check that the names are valid and are not repeated
            stringSet.clear();
            foreach(i, name; n.names) {
                if(stringSet.contains(name)) {
                    throw new CompilerError(n.children[i],
                        "Struct member %s initialised more than once".format(name));
                }
                stringSet.add(name);
                auto v = struct_.getMemberVariable(name);
                if(!v) {
                    throw new CompilerError(n.children[i],
                        "Struct does not have member %s".format(name));
                }
            }

            auto elementTypes = n.elementTypes();

            foreach(i, name; n.names) {
                auto var   = struct_.getMemberVariable(name);

                auto left  = elementTypes[i];
                auto right = var.type;
                if(!left.canImplicitlyCastTo(right)) {
                    errorBadImplicitCast(n.elements()[i], left, right);

                }
            }

        } else {
            /// This is a list of elements

            /// Check that the element types match the struct members
            foreach(i, t; n.elementTypes()) {
                auto left  = t;
                auto right = structTypes[i];
                if(!left.canImplicitlyCastTo(right)) {
                    errorBadImplicitCast(n.elements()[i], left, right);
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
                throw new CompilerError(v,
                    "Global variable %s declared more than once".format(v.name));
            }
            stringSet.add(v.name);
        }
    }
    void visit(NamedStruct n) {
        /// All variables must have a name
        stringSet.clear();
        foreach(v; n.type.getMemberVariables()) {
            if(v.name.length==0) {
                throw new CompilerError(v,
                    "Named struct variable must have a name");
            }
        }
    }
    void visit(Parenthesis n) {

    }
    void visit(Return n) {

    }
    void visit(TypeExpr n) {

    }
    void visit(Unary n) {

    }
    void visit(ValueOf n) {

    }
    void visit(Variable n) {
        if(n.isConst) {
            /// Initialiser must be const
            auto ini = n.initialiser();
            if(!ini.isConst) {
                errorVarInitMustBeConst(n);
            }
        }
        if(n.isStatic) {
            import common : contains;
            if(!n.name.contains("::")) {
                throw new CompilerError(n, "Static variables are not allowed at this scope");
            }
        }

        if(n.type.isStruct) {
            /// Check that member names are unique
            stringSet.clear();
            auto struct_ = n.type.getAnonStruct();
            auto vars    = struct_.getMemberVariables();
            foreach(v; vars) {
                if(v.name) {
                    if(stringSet.contains(v.name))
                        throw new CompilerError(v,
                            "Struct %s has duplicate member %s".format(n.name, v.name));
                    stringSet.add(v.name);
                }
            }
            /// Anon structs must only contain variable declarations
            if(n.type.isAnonStruct) {
                foreach(v; struct_.children) {
                    if(!v.isVariable) {
                        throw new CompilerError(n,
                            "An anonymous struct must only contain variable declarations");
                    } else {
                        auto var = cast(Variable)v;
                        if(var.hasInitialiser) {
                            throw new CompilerError(n,
                            "An anonymous struct must not have variable initialisation");
                        }
                    }
                }
            }
        }
        if(n.isLocal) {
            /// Check for duplicate variable names
            stringSet.clear();
            auto node = n.prevSibling();
            if(!node) node = n.parent;
            auto res = identifierResolver.findFirst(n.name, node);
            if(res.found) {
                if(res.isVar) {
                    auto var = res.var;
                    bool sameScope = var.parent==n.parent;
                    if (sameScope) {
                        throw new CompilerError(n,
                        "Variable %s declared more than once in this scope".format(n.name));
                    }
                    throw new CompilerError(n,
                    "Variable %s is shadowing another variable declared on line %s".format(n.name, var.line));
                } else {
                    /// check function?
                }
            }
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
}