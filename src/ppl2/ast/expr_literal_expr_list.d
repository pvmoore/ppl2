module ppl2.ast.expr_literal_expr_list;

import ppl2.internal;

///
/// "[" { expr { "," expr } } "]"
///
final class LiteralExpressionList : Expression {

    override bool isResolved() { return false; }
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
                } else if(p.getType.isAnonStruct) {
                    convertToLiteralStruct();
                }
                break;
            case BINARY:
                auto p     = parent.as!Binary;
                auto other = p.otherSide(this);
                if(other.getType.isArray) {
                    convertToLiteralArray();
                } else if(other.getType.isAnonStruct) {
                    convertToLiteralStruct();
                }
                break;
            case CALL:
                auto p = parent.as!Call;
                auto t = p.isResolved ? p.target.paramTypes()[index()] : TYPE_UNKNOWN;
                if(t.isArray) {
                    convertToLiteralArray();
                } else if(t.isAnonStruct) {
                    convertToLiteralStruct();
                }
                break;
            case INITIALISER:
                auto p = parent.as!Initialiser;
                if(p.var.isImplicit) {
                    /// Assume array
                    convertToLiteralArray();
                } else if(p.var.type.isArray) {
                    convertToLiteralArray();
                } else if(p.var.type.isAnonStruct) {
                    convertToLiteralStruct();
                }
                break;
            case RETURN:
                auto p = parent.as!Return;
                if(p.getReturnType().isArray) {
                    convertToLiteralArray();
                } else if(p.getReturnType().isAnonStruct) {
                    convertToLiteralStruct();
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
        dd("converting to LiteralArray");
        auto array = makeNode!LiteralArray(this);

        foreach(ch; children[].dup) {
            array.add(ch);
        }

        parent.replaceChild(this, array);
    }
    void convertToLiteralStruct() {
        dd("converting to LiteralStruct");
        auto struct_ = makeNode!LiteralStruct(this);

        foreach(ch; children[].dup) {
            struct_.add(ch);
        }

        parent.replaceChild(this, struct_);
    }
}