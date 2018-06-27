module ppl2.ast.expr_if;

import ppl2.internal;
/**
 *  if_expr ::= "if" bool_expr if_body [ "else" else_body ]
 *  if_body ::= [ "{" ] { statement } [ "}" ]
 *  else_body ::= [ "{" ] { statement } [ "}" ]
 *
 *  This is an expression. All results must produce a result that can be implicitly cast
 *  to a single base type.
 *      eg.
 *  int a = if(b > c) 3 else 4
 *  int a = if(b > c) { callSomeone(); 3 } else if(c > d) 4 else 5
 */
final class If : Expression {

    override bool isResolved() { return false; }
    override NodeID id() const { return NodeID.IF; }
    override int priority() const { return 15; }
    override Type getType() { return TYPE_UNKNOWN; } // todo

    override string toString(){
        return "if (%s)".format(getType());
    }
}