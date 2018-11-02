module ppl2.ast.expr_literal_array;

import ppl2.internal;
///
/// literal_array  ::= "[" init_expr { "," init_expr } "]"
/// init_expr ::= [digits"="] expression | [digits"="] expression
///
/// LiteralArray
///     expr
///     expr etc...
final class LiteralArray : Expression {
    ArrayType type;
    bool isIndexBased;  /// if true, the elements are [(idx)expr, (val)expr, (idx)expr, (val)expr,   etc...]
                        /// if false the elements are [expr, expr,  etc...]

    this() {
        type         = makeNode!ArrayType(this);
        type.subtype = TYPE_UNKNOWN;
        type.add(LiteralNumber.makeConst(0, TYPE_INT));
    }

    override bool isResolved() {
        return type.isKnown;
        //return type.isResolved &&
        //       indexElements().as!(ASTNode[]).areResolved &&
        //       elementValues().as!(ASTNode[]).areResolved;
    }
    override NodeID id() const { return NodeID.LITERAL_ARRAY; }
    override int priority() const { return 15; }
    override Type getType() { return type; }

    int length() {
        assert(isResolved);

        if(isIndexBased) {
            import std.algorithm.searching : maxElement;
            return 1 + elementIndexes.map!(it=>it.as!LiteralNumber.value.getInt()).maxElement();
        }
        return children.length.as!int;
    }

    string generateName() {
        string name = "literal_array";
        ASTNode node = parent;
        while(node) {
            if(node.id==NodeID.VARIABLE) {
                name ~= "_for_" ~ node.as!Variable.name;
                break;
            } else if(node.id==NodeID.IDENTIFIER) {
                name ~= "_for_" ~ node.as!Identifier.name;
                break;
            } else if(node.id==NodeID.LITERAL_FUNCTION) {
                break;
            }
            node = node.parent;
        }
        return name;
    }

    ///
    /// Try to infer the type based on the elements
    ///
    void inferTypeFromElements() {
        if(!elementTypes().areKnown) return;

        if(children.length==0) {
            if(parent.parent.isVariable) {
                auto var = parent.parent.as!Variable;
                if(var.isImplicit) {
                    getModule.addError(this, "Cannot infer type if no array values are specified");
                    return;
                }
            }
        }

        Type t = calculateCommonElementType();
        type.subtype = t;

        if(isIndexBased) {
            auto indices = elementIndexes();
            if(!indices.types.areKnown) return;

            foreach(n; indices) {
                if(!n.isConst) {
                    getModule.addError(n, "Array index expression must be a const");
                    return;
                }
            }

            if(!areAll!(NodeID.LITERAL_NUMBER)(indices.as!(ASTNode[]))) return;
        }


        /// If we get here then we know all we need to know

        type.setCount(LiteralNumber.makeConst(calculateCount()));
    }

    Expression[] elementValues() {
        if(isIndexBased) {
            auto n = new Array!Expression;
            foreach(i, e; children[]) {
                if((i&1)==0) continue;
                n.add(e.as!Expression);
            }
            return n[];
        }
        return cast(Expression[])children[];
    }
    Type[] elementTypes() {
        return elementValues().map!(it=>it.getType).array;
    }
    Expression[] elementIndexes() {
        if(!isIndexBased) return null;
        auto n = new Array!Expression;
        foreach(i, e; children[]) {
            if((i&1)==1) continue;
            n.add(e.as!Expression);
        }
        return n[];
    }

    override string toString() {
        return "[: ] %s%s".format(type, isIndexBased ? " (index based)" : "");
    }
private:
    int calculateCount() {
        if(isIndexBased) {
            /// Indices must be resolvable at compile time to a number

            int largest = 0;
            foreach(n; elementIndexes()) {

                auto lit = n.as!LiteralNumber;

                if(lit.value.getInt() > largest) {
                    largest = lit.value.getInt() + 1;
                }
            }
            return max!int(largest, numChildren / 2);
        }
        return numChildren;
    }
    ///
    /// Get the largest type of all elements.
    /// If there is no super type then return null
    ///
    Type calculateCommonElementType() {
        if(numChildren==0) return TYPE_UNKNOWN;

        auto et = elementTypes();

        Type t = et[0];
        if(et.length==1) return t;

        foreach(e; et[1..$]) {
            t = getBestFit(t, e);
            if(t is null) {
                getModule.addError(this,"Array has no common type");
            }
        }
        return t;
    }
}