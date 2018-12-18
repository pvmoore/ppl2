module ppl2.check.EscapeAnalysis;

import ppl2.internal;
///
/// Simple check for escaping reference to stack allocated memory.
/// This needs much more improvement.
///
/// If the return is a ptr and it is a reference to a local variable then error
///

const string VERBOSE = null; //"misc::escape_analysis";

final class EscapeAnalysis {
private:
    Module module_;
    LiteralFunction body_;
public:
    this(Module m) {
        this.module_ = m;
    }
    void analyse(LiteralFunction body_) {
        FunctionType type = body_.getType.getFunctionType;
        string name = body_.isClosure ? body_.getClosure.name : body_.getFunction.name;
        chat("=================== %s %s", name, type);

        this.body_ = body_;

        if(type.returnType.isPtr) {
            checkVariablesAndAssigns();
        }
    }
private:
    struct Ref {
        int nid;
        string name;
        int ptrDepth;

        this(Variable v) {
            nid = v.nid;
            name = v.name;
            ptrDepth = v.type.getPtrDepth;
        }
        this(Type t, string name) {
            this.nid      = g_nodeid++;
            this.name     = name;
            this.ptrDepth = t.getPtrDepth;
        }
        bool exists() { return nid!=0; }

        string toString() {
            if(!exists()) return "Ref()";
            return "Ref(%s,%s,%s)".format(name,nid,ptrDepth);
        }
    }
    struct PointsTo {
        Ref r;
        bool poison;

        string toString() {
            return "->%s%s".format(r.toString(), poison?"!!!":"");
        }
    }
    alias RefNID = int;
    PointsTo[RefNID] vars;

    //bool hasPtrReturnOrParam(FunctionType type) {
    //    if(type.returnType.isPtr) return true;
    //    foreach(t; type.paramTypes) {
    //        if(containsPtr(t)) return true;
    //    }
    //    return false;
    //}
    //bool containsPtr(Type t) {
    //    if(t.isPtr) return true;
    //    if(t.isTuple) {
    //        foreach(t2; t.getTuple.memberVariableTypes()) {
    //            if(containsPtr(t2)) return true;
    //        }
    //    }
    //    if(t.isStruct) {
    //        foreach(t2; t.getStruct.memberVariableTypes()) {
    //            if(containsPtr(t2)) return true;
    //        }
    //    }
    //    return false;
    //}
    void chat(A...)(lazy string fmt, lazy A args) {
        static if(VERBOSE) {
            if(module_.canonicalName==VERBOSE)
            dd(format(fmt, args));
        }
    }

    Ref findVariable(Expression e) {
        switch(e.id) with(NodeID) {
            case ADDRESS_OF:
                return findVariable(e.as!AddressOf.expr());
            case AS:
                return findVariable(e.as!As.left());
            case CALL:
                break;
            case DOT:
                auto dot = e.as!Dot;
                return findVariable(dot.right());
            case IDENTIFIER:
                auto target = e.as!Identifier.target;
                if(target.isVariable) return Ref(target.getVariable);
                break;
            case INDEX:
                auto idx = e.as!Index;
                return Ref(idx.getType, "index");
            case LITERAL_ARRAY:
            case LITERAL_NULL:
            case LITERAL_NUMBER:
            case LITERAL_TUPLE:
            case BINARY:
            case CLOSURE:
                break;

            default:
                assert(false, "implement %s".format(e.id));
                //break;
        }
        return Ref();
    }
    T probeFor(T)(Expression e) {
        if(e.isA!T) {
            return e.as!T;
        }
        switch(e.id) with(NodeID) {
            case ADDRESS_OF: return probeFor!T(e.as!AddressOf.expr());
            case LITERAL_ARRAY:
            case LITERAL_NULL:
            case LITERAL_TUPLE:
            case BINARY:
            case CALL:
                break;
            default:
                assert(false, "implement %s".format(e.id));
        }
        return null;
    }
    void checkVariablesAndAssigns() {


        void error(ASTNode n) {
            module_.addError(n, "Escaping reference to stack memory", true);
        }

        body_.recurse!ASTNode((n) {
            if(n.id==NodeID.VARIABLE) {
                auto var = n.as!Variable;
                chat(" var %s (%s)", var.name, var.nid);
                vars[n.nid] = PointsTo();
            } else if(n.id==NodeID.BINARY && n.as!Binary.op==Operator.ASSIGN) {
                auto bin   = n.as!Binary;
                auto left  = findVariable(bin.left());
                auto right = findVariable(bin.right());

                if(left.exists && right.exists) {

                    PointsTo rightPT = vars.get(right.nid, PointsTo());

                    chat(" %s(%s) = %s(%s)", left.name, left.nid, right.name, right.nid);
                    vars[left.nid] = PointsTo(right, bin.rightType.isPtr || rightPT.poison);
                } else if(left.exists) {
                    /// reset left
                    chat(" %s(%s) = ?", left.name, left.nid);
                    vars[left.nid] = PointsTo();
                }
            } else if(n.id==NodeID.RETURN) {
                auto ret = n.as!Return;
                if(ret.getType.isPtr) {
                    int depth = ret.getType.getPtrDepth;
                    chat("      return ptr depth:%s ==> vars = %s", depth, vars);

                    auto var = findVariable(ret.expr());
                    if(var.exists) {
                        if(var.ptrDepth < depth) {
                            chat("POISON");
                            error(ret.expr());
                        } else {
                            auto pointsTo = vars.get(var.nid, PointsTo());
                            chat(" ret = %s, %s", var, pointsTo);
                            if(pointsTo.poison) {
                                chat("POISON");
                                error(ret.expr());
                            }
                        }
                    } else {
                        if(probeFor!LiteralArray(ret.expr()) ||
                           probeFor!LiteralTuple(ret.expr()))
                        {
                            chat("POISON");
                            error(ret.expr());
                        }
                    }
                }
            }
        });
    }
}