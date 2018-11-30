module ppl2.ast.expr_literal_tuple;

import ppl2.internal;
///
/// literal_tuple ::= "[" tuple_param { "," tuple_param } "]"
/// tuple_param   ::= expression | name "=" expression
///
/// LiteralTuple
///     expression
///     expression etc...
///
final class LiteralTuple : Expression {
    Type type;
    string[] names;  /// name = expression

    this() {
        type = TYPE_UNKNOWN;
    }

    override bool isResolved()    { return type.isKnown; }
    override NodeID id() const    { return NodeID.LITERAL_TUPLE; }
    override int priority() const { return 15; }
    override Type getType()       { return type; }

    ///
    /// Try to infer the type based on the elements.
    /// Should only need to do this eg. in the following scenarios:
    ///     var a = [1,2]
    ///     [1,2][index]
    ///
    Tuple getInferredType() {
        if(!areKnown(elementTypes())) return null;

        auto t = makeNode!Tuple(this);

        if(names.length>0) {
            /// name = value

            auto types = elementTypes();
            assert(types.length==names.length);

            foreach(i, n; names) {
                auto v = makeNode!Variable(this);
                v.name = n;
                v.type = types[i];
                t.add(v);
            }
        } else {
            /// This is a standard list of expressions

            /// Create a child Variable for each member type
            foreach (ty; elementTypes) {
                auto v = makeNode!Variable(this);
                v.type = ty;
                t.add(v);
            }
        }
        /// Add this Tuple at module scope because we need it to be in the AST
        /// but we don't want it as our own child node
        getModule.add(t);

        return t;
    }

    int numElements() {
        return children.length.as!int;
    }
    Expression[] elements() {
        return cast(Expression[])children[];
    }
    Type[] elementTypes() {
        return elements().map!(it=>it.getType).array;
    }
    bool allValuesSpecified() {
        assert(isResolved);
        return elements().length == type.getTuple.numMemberVariables;
    }

    override string toString() {
        return "[] %s".format(type);
    }
private:
}