module ppl2.ast.expr_dot;

import ppl2.internal;
///
/// dot        ::= member_dot | scope_dot
/// member_dot ::= expression "." expression
/// scope_dot  ::= expression "::" expression
///
final class Dot : Expression {
    enum DotType {
        MEMBER,     //  struct.member
        STATIC,     //  Struct::member
        MODULE      //  Module::member
    }
    DotType dotType = DotType.MEMBER;

    override bool isResolved() { return getType.isKnown; }
    override NodeID id() const { return NodeID.DOT; }
    override int priority() const { return 2; }
    override Type getType() {
        if(right() is null) return TYPE_UNKNOWN;
        return right().getType;
    }

    Expression left() { return cast(Expression)first(); }
    Expression right() { return cast(Expression)last(); }

    bool isMemberAccess() const { return dotType==DotType.MEMBER; }
    bool isStaticAccess() const { return dotType==DotType.STATIC; }
    bool isModuleAccess() const { return dotType==DotType.MODULE; }

    void resolve() {
        if(dotType==DotType.STATIC) {
            /// todo - Find out whether lhs is a struct or a module

            // For now it is always a struct
        }
    }

    override string toString() {
        string s = dotType==DotType.MEMBER ? "." : "::";
        return "%s (type=%s)".format(s, getType);
    }
}