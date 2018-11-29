module ppl2.resolve.resolve_literals;

import ppl2.internal;

final class LiteralResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(LiteralArray n) {
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
                case BUILTIN_FUNC:
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
    void resolve(LiteralExpressionList n) {
        /// Try to convert this into either a LiteralTuple or a LiteralArray
        n.resolve();
        resolver.setModified();
    }
    void resolve(LiteralFunction n) {
        if(n.type.isUnknown) {

            auto ty = n.type.getFunctionType;
            if(ty.returnType.isUnknown) {
                ty.returnType = n.determineReturnType();
            }
        }
    }
    void resolve(LiteralMap n) {
        assert(false, "implement visit.LiteralMap");
    }
    void resolve(LiteralNull n) {
        if(n.type.isUnknown) {
            auto parent = n.getParentIgnoreComposite();

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
                    auto c = parent.as!Case;
                    if(c.isCond(n)) {
                        type = c.getSelectType();
                    }
                    break;
                case IF:
                    auto if_ = parent.as!If;
                    if(n.isAncestor(if_.thenStmt())) {
                        type = if_.thenType();
                    } else if(if_.hasElse && n.isAncestor(if_.elseStmt())) {
                        type = if_.elseType();
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
            } else if(resolver.isStalemate) {
                module_.addError(n, "Ambiguous null requires explicit cast", true);
            }
        }
    }
    void resolve(LiteralNumber n) {
        if(n.type.isUnknown) {
            n.determineType();
        }
        if(n.type.isKnown) {

        }
    }
    void resolve(LiteralString n) {
        if(n.type.isUnknown) {
            resolver.resolveAlias(n, n.type);
        }
    }
    void resolve(LiteralTuple n) {
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
                case BUILTIN_FUNC:
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
                    assert(false, "Parent of LiteralTuple is %s".format(n.parent.id));
            }
            if(type && type.isKnown) {
                if(!type.isTuple) {
                    module_.addError(n, "Cannot cast tuple literal to %s".format(type), true);
                    return;
                }
                n.type = type;
            }
        }
        if(!n.isResolved && resolver.isStalemate) {
            module_.addError(n, "Ambiguous tuple literal requires explicit cast", true);
        }
    }
}