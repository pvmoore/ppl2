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
///    composite initExprs
///    condition
///    thenStmt
///    elseStmt // optional
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

        if(p.id==NodeID.LITERAL_FUNCTION ||
           p.id==NodeID.LOOP)
        {
            return false;
        }
        if(p.id==NodeID.BINARY ||
           p.id==NodeID.INITIALISER ||
           p.id==NodeID.RETURN)
        {
            return true;
        }
        if(p.id==NodeID.IF) return p.as!If.isExpr();

        assert(false, "dunno parent=%s".format(p));
    }
    bool thenBlockEndsWithReturn() {
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