module ppl2.ast.expr_index;

import ppl2.internal;
///
/// index_expr ::= expression ":" expression
///
/// Index
///     index
///     ArrayType | Tuple | PtrType
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
            auto ns = exprType().getNamedStruct;
            assert(ns);
            if(ns.getMemberFunctions("operator:")) return false;
        }
        /// Struct index must be a const number
        return index().isResolved && index().isA!LiteralNumber;
    }
    override NodeID id() const { return NodeID.INDEX; }
    override int priority() const { return 2; }

    override Type getType() {
        /// This might happen if an error is thrown
        if(numChildren < 2) return TYPE_UNKNOWN;

        auto t     = exprType();
        auto tuple = t.getTuple;
        auto ns    = t.getNamedStruct;
        auto array = t.getArrayType;

        if(t.isPtr) {
            return PtrType.of(t, -1);
        }
        if(t.isNamedStruct) {
            assert(ns);
            if(ns.hasOperatorOverload(Operator.INDEX)) {
                /// This will be replaced with an operator overload later
                return TYPE_UNKNOWN;
            }
        }
        if(array) {
            /// Check for bounds error
            if(array.isResolved && index().isResolved && index().isA!LiteralNumber) {
                auto i = getIndexAsInt();
                if(i >= array.countAsInt()) {
                    getModule.addError(index(), "Array bounds error. %s >= %s".format(i, array.countAsInt()), true);
                    return TYPE_UNKNOWN;
                }
            }
            return array.subtype;
        }
        if(tuple) {
            if(index().isResolved && index().isA!LiteralNumber) {
                auto i = getIndexAsInt();
                /// Check for bounds error
                if(i >= tuple.numMemberVariables()) {
                    getModule.addError(index(), "Array bounds error. %s >= %s".format(i, tuple.numMemberVariables()), true);
                    return TYPE_UNKNOWN;
                }
                return tuple.getMemberVariable(i).type;
            }
        }
        return TYPE_UNKNOWN;
    }

    bool isArrayIndex()  { return exprType().isValue && exprType().isArray; }
    bool isStructIndex() { return exprType().isValue && exprType().isTuple; }
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