module ppl2.ast.expr_literal_expr_list;

import ppl2.internal;

///
/// "[" { expr { "," expr } } "]"
///
final class LiteralExpressionList : Expression {

    override bool isResolved() {
        /// This node will be removed before all nodes are resolved
        return false;
    }
    override NodeID id() const { return NodeID.LITERAL_EXPR_LIST; }
    override int priority() const { return 15; }
    override Type getType() { return TYPE_UNKNOWN; }

    void resolve() {
        switch(parent.id) with(NodeID) {
            case AS:
                As p   = parent.as!As;
                auto t = p.getType;
                if(p.getType.isArray) {
                    if(t.getArrayType.numChildren==0) {
                        /// No length eg. [1,2,3] as type[]

                        auto count = LiteralNumber.makeConst(numChildren, TYPE_INT);
                        t.getArrayType.add(count);
                    }
                    convertToLiteralArray();
                } else if(p.getType.isTuple) {
                    convertToLiteralTuple();
                }
                break;
            case BINARY:
                auto p     = parent.as!Binary;
                auto other = p.otherSide(this);
                if(other.getType.isArray) {
                    convertToLiteralArray();
                } else if(other.getType.isTuple) {
                    convertToLiteralTuple();
                }
                break;
            case CALL:
                auto p = parent.as!Call;
                auto t = p.isResolved ? p.target.paramTypes()[index()] : TYPE_UNKNOWN;
                if(t.isArray) {
                    convertToLiteralArray();
                } else if(t.isTuple) {
                    convertToLiteralTuple();
                } else {
                    /// Assume array
                    convertToLiteralArray();
                }
                break;
            case ADDRESS_OF:
            case BUILTIN_FUNC:
            case DOT:
            case INDEX:
            case LITERAL_FUNCTION:
                /// Assume array
                convertToLiteralArray();
                break;
            case INITIALISER:
                auto p = parent.as!Initialiser;
                if(p.var.isImplicit) {
                    /// Assume array
                    convertToLiteralArray();
                } else if(p.var.type.isArray) {
                    convertToLiteralArray();
                } else if(p.var.type.isTuple) {
                    convertToLiteralTuple();
                }
                break;
            case IS:
                auto p = parent.as!Is;
                auto t = p.oppositeSideType(this);
                if(t.isArray) {
                    convertToLiteralArray();
                } else if(t.isTuple) {
                    convertToLiteralTuple();
                }
                break;
            case RETURN:
                auto p = parent.as!Return;
                if(p.getReturnType().isArray) {
                    convertToLiteralArray();
                } else if(p.getReturnType().isTuple) {
                    convertToLiteralTuple();
                }
                break;
            default:
                assert(false, "Parent of LiteralExpressionList is %s".format(parent.id));
        }
    }

    override string toString() {
        return "Literal array or struct";
    }
private:
    void convertToLiteralArray() {
        auto array = makeNode!LiteralArray(this);

        foreach(ch; children[].dup) {
            array.add(ch);
        }

        parent.replaceChild(this, array);
    }
    void convertToLiteralTuple() {
        auto struct_ = makeNode!LiteralTuple(this);

        foreach(ch; children[].dup) {
            struct_.add(ch);
        }

        parent.replaceChild(this, struct_);
    }
}