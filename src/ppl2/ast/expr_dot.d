module ppl2.ast.expr_dot;

import ppl2.internal;
///
/// dot        ::= member_dot | scope_dot
/// member_dot ::= expression "." expression
/// scope_dot  ::= expression "::" expression
///
final class Dot : Expression {
    enum DotType {
        INSTANCE,   //  expr.member
        STATIC      //  Struct::member, Module::member or Enum::member
    }
    DotType dotType = DotType.INSTANCE;

    override bool isResolved() { return getType.isKnown && left().isResolved && right().isResolved; }
    override NodeID id() const { return NodeID.DOT; }
    override int priority() const { return 2; }
    override Type getType() {
        if(right() is null) return TYPE_UNKNOWN;
        return right().getType;
    }

    Expression left()  { return cast(Expression)first(); }
    Expression right() { return cast(Expression)last(); }

    Type leftType()  { return left().getType; }
    Type rightType() { return right().getType; }

    bool isInstanceAccess() const { return dotType==DotType.INSTANCE; }
    bool isStaticAccess() const   { return dotType==DotType.STATIC; }

    override string toString() {
        string s = dotType==DotType.INSTANCE ? "." : "::";
        return "%s (type=%s)".format(s, getType);
    }
}