module ppl2.ast.expr_if;

import ppl2.internal;
///
/// if_expr   ::= "if" bool_expr if_body [ "else" else_body ]
/// if_body   ::= [ "{" ] { statement } [ "}" ]
/// else_body ::= [ "{" ] { statement } [ "}" ]
///
/// This is an expression. All results must produce a result that can be implicitly cast
/// to a single base type.
///     eg.
/// int a = if(b > c) 3 else 4
/// int a = if(b > c) { callSomeone(); 3 } else if(c > d) 4 else 5
///
/// If
///    [0] initExprs (Composite)
///    [1] condition (Expression)
///    [2] thenStmt  (Composite)
///    [3] elseStmt // optional (Composite)
///
final class If : Expression {
    Type type;

    this() {
        type = TYPE_UNKNOWN;
    }

    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.IF; }
    override int priority() const { return 15; }
    override Type getType() { return type; }

    Composite initExprs()  { return children[0].as!Composite; }
    Expression condition() { return children[1].as!Expression; }
    Composite thenStmt()   { return children[2].as!Composite; }
    Composite elseStmt()   { return children[3].as!Composite; }

    Type thenType() { return thenStmt().getType(); }
    Type elseType() { assert(hasElse); return elseStmt().getType(); }

    bool hasInitExpr() { return first().hasChildren; }
    bool hasThen()     { return thenStmt().hasChildren; }
    bool hasElse()     { return numChildren > 3 && elseStmt().hasChildren; }

    bool isExpr() {
        auto p = parent;
        while(p.id==NodeID.COMPOSITE) p = p.parent;

        switch(p.id) with(NodeID) {
            case LITERAL_FUNCTION:
            case LOOP:
                return false;
            case SELECT:
                if(parent.isComposite) {
                    if(parent.last().nid == nid) return p.as!Select.isExpr;
                } else {
                    assert(false, "implement me");
                }
                assert(false, "implement me");
            case BINARY:
            case INITIALISER:
            case RETURN:
            case ADDRESS_OF:
            case VALUE_OF:
            case PARENTHESIS:
                return true;
            case IF:
                return p.as!If.isExpr();
            default:
                assert(false, "dunno p=%s parent=%s".format(p, parent));
        }
    }
    bool thenBlockEndsWithReturn() {
        if(thenStmt.numChildren==0) return false;
        return thenStmt().last().isReturn;
    }
    bool elseBlockEndsWithReturn() {
        assert(hasElse);
        return elseStmt().last().isReturn;
    }

    override string toString(){
        string e = isExpr ? "EXPR" : "STMT";
        return "If %s (type=%s)".format(e, getType());
    }
}