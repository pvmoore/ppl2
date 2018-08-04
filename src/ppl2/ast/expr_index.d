module ppl2.ast.expr_index;

import ppl2.internal;
///
/// index_expr ::= expression ":" expression
///
/// Index
///     index
///     ArrayType | AnonStruct | PtrType
///
final class Index : Expression {

    override bool isResolved() {
        if(!expr().isResolved) return false;
        if(isArrayIndex()) {
            return index().isResolved;
        }
        if(isPtrIndex) {
            return true;
        }
        if(exprType().isNamedStruct) {
            /// Check if we are waiting to be rewritten to operator:
            auto struct_ = exprType().getAnonStruct;
            assert(struct_);
            if(struct_.getMemberFunctions("operator:")) return false;
        }
        /// Struct index must be a const number
        return index().isResolved && index().isA!LiteralNumber;
    }
    override NodeID id() const { return NodeID.INDEX; }
    override int priority() const { return 2; }

    override Type getType() {
        /// This might happen if an error is thrown
        if(numChildren < 2) return TYPE_UNKNOWN;

        auto t       = exprType();
        auto struct_ = t.getAnonStruct;
        auto array   = t.getArrayStruct;

        if(t.isPtr) {
            return PtrType.of(t, -1);
        }
        if(t.isNamedStruct) {
            assert(struct_);
            if(struct_.hasOperatorOverload(Operator.INDEX)) {
                /// This will be replaced with an operator overload later
                return TYPE_UNKNOWN;
            }
        }
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

    bool isArrayIndex()  { return exprType().isValue && exprType().isArrayStruct; }
    bool isStructIndex() { return exprType().isValue && exprType().isAnonStruct; }
    bool isPtrIndex()    { return exprType().isPtr; }

    Expression expr()  { return cast(Expression)children[1]; }
    Expression index() { return cast(Expression)children[0]; }

    Type exprType() { return expr().getType; }

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