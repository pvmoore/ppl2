module ppl2.resolve.resolve_identifier;

import ppl2.internal;

const string VERBOSE = null; //"core::list";

///
/// Resolve an identifier.
/// All identifiers must be found within the same module.
///
final class IdentifierResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    this(ModuleResolver resolver, Module module_) {
        this(module_);
        this.resolver = resolver;
    }
    struct Result {
        union {
            Variable var;
            Function func;
        }
        bool isVar;
        bool isFunc;

        void set(Variable v) {
            this.var   = v;
            this.isVar = true;
        }
        void set(Function f) {
            this.func   = f;
            this.isFunc = true;
        }
        int line() {
            return isVar ? var.line : isFunc ? func.line : -1;
        }

        bool found() { return isVar || isFunc; }
    }
    ///==================================================================================
    Result find(string name, ASTNode node) {
        Result res;

        chat("  %s %s", name, node.id);

        /// Check previous siblings at current level
        foreach(n; node.prevSiblings()) {
            isThisIt(name, n, res);
            if(res.found) return res;
        }

        auto p = node.parent;
        if(p.isComposite) p = p.previous();

        /// Recurse up the tree
        findRecurse(name, p, res);

        return res;
    }
    ///==================================================================================
    void resolve(Identifier n) {
        assert(resolver);

        if(!n.target.isResolved) {
            if(n.isStartOfChain()) {
                findLocalOrGlobal(n);
            } else {
                findStructMember(n);
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
                    resolver.fold(n, lit.copy());
                    n.target.dereference();
                    return;
                }
            }
        }
    }
private:
    ///==================================================================================
    void findRecurse(string name, ASTNode node, ref Result res) {

        isThisIt(name, node, res);
        if(res.found) return;

        auto nid = node.id();

        switch(nid) with(NodeID) {
            case MODULE:
            case TUPLE:
            case STRUCT:
                /// Check all variables at this level
                foreach(n; node.children) {
                    isThisIt(name, n, res);
                    if(res.found) return;
                }

                if(nid==MODULE) return;

                /// Go to module scope
                findRecurse(name, node.getModule(), res);
                return;
            case LITERAL_FUNCTION:
                if(!node.as!LiteralFunction.isClosure) {
                    /// Go to containing struct if there is one
                    auto ns = node.getAncestor!Struct();
                    if(ns) {
                        findRecurse(name, ns, res);
                        return;
                    }
                }
                /// Go to module scope
                findRecurse(name, node.getModule(), res);
                return;
            default:
                break;
        }

        /// Check variables that appear before this in the tree
        foreach(n; node.prevSiblings()) {
            isThisIt(name, n, res);
            if(res.found) return;
        }

        findRecurse(name, node.parent, res);
    }
    void isThisIt(string name, ASTNode n, ref Result res) {

        switch(n.id) with(NodeID) {
            case COMPOSITE:
                /// Treat children of Composite as if they were in scope
                foreach(n2; n.children) {
                    isThisIt(name, n2, res);
                    if(res.found) break;
                }
                break;
            case VARIABLE: {
                auto v = n.as!Variable;
                if(v.name==name) res.set(v);
                break;
            }
            case PARAMETERS: {
                auto v = n.as!Parameters.getParam(name);
                if(v) res.set(v);
                break;
            }
            case FUNCTION: {
                auto f = n.as!Function;
                if(f.name==name) res.set(f);
                break;
            }
            default:
                break;
        }
    }
    void findLocalOrGlobal(Identifier n) {
        auto res = find(n.name, n);
        if(!res.found) {
            /// Ok to continue
            module_.addError(n, "identifier '%s' not found".format(n.name), true);
            return;
        }

        if(res.isFunc) {
            auto func = res.func;

            module_.buildState.functionRequired(func.moduleName, func.name);

            if(func.isStructMember) {
                auto ns = n.getAncestor!Struct();
                assert(ns);

                n.target.set(func, ns.getMemberIndex(func));
            } else {
                /// Global, local or parameter
                n.target.set(func);
            }
        } else {
            Variable var = res.isVar ? res.var : null;

            if(var.isStructMember) {
                auto struct_ = n.getAncestor!Struct();
                assert(struct_);

                n.target.set(var, struct_.getMemberIndex(var));

            } else if(var.isTupleMember) {
                auto tuple = n.getAncestor!Tuple();
                assert(tuple);

                n.target.set(var, tuple.getMemberIndex(var));

            } else {
                /// Global, local or parameter
                n.target.set(var);
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
        }
    }
    void findStructMember(Identifier n) {
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

        // check this - it might be ok since each dot resolves itself in order
        // todo - this dot may not be the one we want if we have a complex chain eg imp::static.length
        // todo - in this case we might need a findStartOfChain method

        /// Properties:
        switch(n.name) {
            case "length":
                if(prevType.isArray) {
                    int len = prevType.getArrayType.countAsInt();
                    resolver.fold(dot, LiteralNumber.makeConst(len, TYPE_INT));
                    return;
                } else if(prevType.isTuple) {
                    int len = prevType.getTuple.numMemberVariables();
                    resolver.fold(dot, LiteralNumber.makeConst(len, TYPE_INT));
                    return;
                } else if(prevType.isEnum) {
                    int len = prevType.getEnum.numChildren;
                    resolver.fold(dot, LiteralNumber.makeConst(len, TYPE_INT));
                    return;
                }
                break;
            case "subtype":
                // todo change this to elementtype

                /// for arrays only
                if(prevType.isArray) {
                    resolver.fold(dot, TypeExpr.make(prevType.getArrayType.subtype));
                    return;
                } else if(prevType.isEnum) {
                    assert(false, "implement me");
                }
                break;
            case "ptr": {
                if(resolver.isAStaticTypeExpr(prev)) break;

                auto b = module_.builder(n);
                As as;
                if(prevType.isArray) {
                    as = b.as(b.addressOf(prev), Pointer.of(prevType.getArrayType.subtype, 1));
                } else if(prevType.isTuple) {
                    as = b.as(b.addressOf(prev), Pointer.of(prevType.getTuple, 1));
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
                resolver.fold(dot, as);
                return;
            }
            case "value":
                /// Enum.ONE.value
                if(prevType.isEnum) {
                    auto em = prev.as!EnumMember;
                    if(em) {
                        resolver.fold(dot, em.expr());
                        return;
                    } else {
                        /// identifier.value
                        auto emv  = makeNode!EnumMemberValue(n);
                        emv.enum_ = prevType.getEnum;
                        emv.add(dot.left());

                        resolver.fold(dot, emv);
                        return;
                    }
                }
                break;
            default:
                break;
        }

        if(!prevType.isStruct && !prevType.isTuple && !prevType.isEnum) {
            module_.addError(prev, "Left of identifier %s must be a struct or enum type not a %s (prev=%s)".format(n.name, prevType, prev), true);
            return;
        }

        Variable var;
        int index;

        /// Is it an enum member?
        Enum e = prevType.getEnum;
        if(e) {
            /// Replace Dot with EnumMember
            auto em = e.member(n.name);
            if(!em) {
                module_.addError(n, "Enum member %s not found".format(n.name), true);
                return;
            }

            resolver.fold(dot, ExpressionRef.make(em));
            return;
        }

        /// Is it a static member?
        Struct struct_ = prevType.getStruct;
        if(struct_) {
            var = struct_.getStaticVariable(n.name);
            if(var) {
                if(var.access.isPrivate && var.getModule.nid != module_.nid) {
                    module_.addError(n, "%s is private".format(var.name), true);
                }
                n.target.set(var);
                return;
            }
        }

        /// It must be an instance member
        Tuple tuple = prevType.getTuple;
        assert(tuple || struct_);

        if(tuple) {
            var   = tuple.getMemberVariable(n.name);
            if(!var) {
                module_.addError(n, "Tuple member '%s' not found".format(n.name), true);
                return;
            }
            index = tuple.getMemberIndex(var);
        } else {
            var = struct_.getMemberVariable(n.name);
            if(!var) {
                module_.addError(n, "Struct '%s' does not have member '%s'".format(struct_.name, n.name), true);
                return;
            }
            index = struct_.getMemberIndex(var);
        }

        if(var) {
            if(var.access.isPrivate && var.getModule.nid != module_.nid) {
                module_.addError(n, "%s is private".format(var.name), true);
            }
            n.target.set(var,index);
        }
    }
    void chat(A...)(lazy string fmt, lazy A args) {
        static if(VERBOSE) {
            if(module_.canonicalName==VERBOSE) {
                dd(format(fmt, args));
            }
        }
    }
}