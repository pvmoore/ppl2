module ppl2.ast.expr_constructor;

import ppl2.internal;

/// S(...)
///    Variable _temp (type=S)
///    Dot
///       _temp
///       Call new
///          addressof(_temp)
///    _temp

/// S*(...)
///    Variable _temp (type=S*)
///    _temp = calloc
///    Dot
///       _temp
///       Call new
///          _temp
///    _temp
///
final class Constructor : Expression {
    Type type;               /// Struct (or Alias resolved to Struct)

    override bool isResolved() { return type.isKnown; }
    override bool isConst() { return false; }
    override int priority() const { return 15; }
    override NodeID id() const { return NodeID.CONSTRUCTOR; }
    override Type getType() { return type; }

    string getName() {
        return type.isStruct ? type.getStruct.name : type.getAlias.name;
    }
    override string toString() {
        return "Constructor %s%s".format(getName(), type.isPtr ? "*":"");
    }
}