module ppl2.ast.expr_index;

import ppl2.internal;
///
/// index_expr ::= expression ":" expression
///
/// Index
///     array | struct | ptr
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
        auto t = leftType();
        if(t.isPtr) {
            return PtrType.of(t, -1);
        }
        auto array = t.getArrayType;
        if(array) {
            /// Check for bounds error
            if(array.isResolved && index().isResolved && index().isA!LiteralNumber) {
                auto i = getIndexAsInt();
                if(i >= array.countAsInt()) {
                    errorArrayBounds(index(), i, array.countAsInt());
                }
            }
            return array.subtype;
        }
        auto struct_ = t.getAnonStruct;
        if(struct_) {
            if(index().isResolved && index().isA!LiteralNumber) {
                auto i = getIndexAsInt();
                /// Check for bounds error
                if(i >= struct_.numMemberVariables()) {
                    errorArrayBounds(index(), i, struct_.numMemberVariables());
                }
                return struct_.getMemberVariable(i).type;
            }
        }
        return TYPE_UNKNOWN;
    }

    bool isArrayIndex() { return leftType().isValue && leftType().isArray; }
    bool isStructIndex() { return leftType().isValue && leftType().isStruct; }
    bool isPtrIndex() { return leftType().isPtr; }

    Expression index() { return cast(Expression)children[1]; }
    Expression left() { return cast(Expression)children[0]; }

    Type leftType() { return left().getType; }

    int getIndexAsInt() {
        assert(index().isA!LiteralNumber);
        return index().as!LiteralNumber.value.getInt();
    }

    override string toString() {
        /// Catch and ignore the exception that might be thrown by calling getType() here
        Type t = TYPE_UNKNOWN;
        try{
            t = getType();
        }catch(Exception e) {}

        return "Index (type=%s) [%s]".format(t, index());
    }
}