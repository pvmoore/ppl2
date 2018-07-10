module ppl2.ast.expr_index;

import ppl2.internal;
///
/// index_expr ::= expression ":" expression
///
/// Index
///     array | struct
///     index
///
final class Index : Expression {

    override bool isResolved() {
        if(!left().isResolved) return false;
        if(isArrayIndex()) {
            return index().isResolved;
        }
        /// Struct index must be a const number
        return index().isResolved && index().isA!LiteralNumber;
    }
    override NodeID id() const { return NodeID.INDEX; }
    override int priority() const { return 1; }

    override Type getType() {
        auto t     = leftType();
        auto array = t.getArrayType;
        if(array) {
            return array.subtype;
        }
        auto struct_ = t.getAnonStruct;
        if(struct_) {


            if(index().isResolved && index().isA!LiteralNumber) {
                auto i = index().as!LiteralNumber.value.getInt();
                if(i < struct_.numMemberVariables()) {
                    return struct_.getMemberVariable(i).type;
                }
                /// An array bounds error will be generated in the semantic checks
                return TYPE_INT;
            }
        }
        if(t.isPtr) {
            return t.getValueType;
        }
        return TYPE_UNKNOWN;
    }

    bool isArrayIndex() { return leftType().isArray; }
    bool isStructIndex() { return leftType().isStruct; }
    bool isPtrIndex() { return leftType().isPtr; }

    Expression index() { return cast(Expression)children[1]; }
    Expression left() { return cast(Expression)children[0]; }

    Type leftType() { return left().getType; }

    int getIndexAsInt() {
        assert(index().isA!LiteralNumber);
        return index().as!LiteralNumber.value.getInt();
    }

    override string toString() {
        return "Index (%s) :%s".format(getType(), index());
    }
}