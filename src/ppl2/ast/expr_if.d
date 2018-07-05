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
///    condition expression
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

    Expression condition() { assert(numChildren>0); return children[0].as!Expression; }
    ASTNode thenStmt() { assert(hasThen); return children[1]; }
    ASTNode elseStmt() { assert(hasElse); return children[2]; }
    Type thenType() { assert(hasThen); return thenStmt().getType(); }
    Type elseType() { assert(hasElse); return elseStmt().getType(); }

    bool hasThen() { return numChildren > 1; }
    bool hasElse() { return numChildren > 2; }

    bool isUsedAsExpr() {
        return !parent.isLiteralFunction;
    }
    bool thenBlockEndsWithReturn() {
        assert(hasThen);
        auto stmt = thenStmt();
        if(stmt.isReturn) return true;
        if(stmt.isComposite) {
            return stmt.last().isReturn;
        }
        return false;
    }
    bool elseBlockEndsWithReturn() {
        assert(hasElse);
        auto stmt = elseStmt();
        if(stmt.isReturn) return true;
        if(stmt.isComposite) {
            return stmt.last().isReturn;
        }
        return false;
    }

    override string toString(){
        return "If (type=%s)".format(getType());
    }
}