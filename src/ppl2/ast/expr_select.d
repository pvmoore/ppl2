module ppl2.ast.expr_select;

import ppl2.internal;
/// Select switch:
///     select_expr ::= "select" "(" [ var  ";" ] expr ")" "{" { ( case | else_case ) } "}"
///     case        ::= const_expr ":" ( stmt | "{" { stmt } "}" )
///     else_case   ::= "else"     ":" ( stmt | "{" { stmt } "}" )
///
///     Children:
///         [0]    init statements  (Composite)
///         [1]    value expression (Expression)
///         [2..$] case expressions (Case[]) | default case (Composite)
///
/// Select Statement:
///     select    ::= "select" "{" { ( case | else_case ) } "}"
///     case      ::= expr   ":" ( stmt | "{" { stmt } "}" )
///     else_case ::= "else" ":" ( stmt | "{" { stmt } "}" )
///
///     Children:
///         [0..$] case expressions (Case[]) | default case (Composite)
///
final class Select : Expression {
    Type type;
    bool isSwitch;

    this() {
        type = TYPE_UNKNOWN;
    }

    override bool isResolved() {
        return isExpr() ? type.isKnown : true;
    }
    override NodeID id() const    { return NodeID.SELECT; }
    override bool isConst()       { return false; }
    override int priority() const { return 15; }
    override Type getType()       { return type; }

    bool hasInitExpr() { assert(isSwitch); return first().hasChildren; }

    bool isExpr() {
        auto p = parent;
        while(p.id==NodeID.COMPOSITE) p = p.parent;

        switch(p.id) with(NodeID) {
            case LITERAL_FUNCTION:
            case LOOP:
                return false;
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
                assert(false, "dunno parent=%s".format(p));
        }
    }

    Composite initExprs() {
        assert(isSwitch);
        return children[0].as!Composite;
    }
    Expression valueExpr() {
        assert(isSwitch);
        return children[1].as!Expression;
    }
    Type valueType() {
        assert(isSwitch);
        return valueExpr().getType;
    }

    /// All cases except the default case
    Case[] cases() {
        ASTNode[] nodes;
        if(isSwitch) {
            nodes = children[2..$];
        } else {
            nodes = children[];
        }
        return cast(Case[])nodes.filter!(it=>it.isCase).array;
    }
    /// The default case or null
    Composite defaultStmts() {
        ASTNode[] nodes;
        if(isSwitch) {
            nodes = children[2..$];
        } else {
            nodes = children[];
        }
        return nodes.filter!(it=>it.isComposite).frontOrNull!Composite;
    }
    Expression[] casesIncludingDefault() {
        return cast(Expression[])(isSwitch ? children[2..$] : children[]);
    }

    override string toString() {
        string e = isExpr() ? "EXPR" : "STMT";
        return "Select %s (type=%s)".format(e, type);
    }
}
///
/// case ::= expr "{" { stmt } "}"
///
final class Case : Expression {
    override bool isResolved()    { return true; }
    override NodeID id() const    { return NodeID.CASE; }
    override bool isConst()       { return false; }
    override int priority() const { return 15; }
    override Type getType()       { return stmts().getType; }

    Expression cond()    { return children[0].as!Expression; }
    Expression[] conds() { return children[0..$-1].as!(Expression[]); }
    Composite stmts()    { return children[$-1].as!Composite; }

    Type getSelectType() {
        assert(parent.isSelect);
        return parent.as!Select.valueType();
    }
    bool isCond(Expression e) {
        foreach(c; conds()) { if(c.nid == e.nid) return true; }
        return false;
    }

    override string toString() {
        return "Case (type=%s)".format(getType);
    }
}