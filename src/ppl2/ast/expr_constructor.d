module ppl2.ast.expr_constructor;

import ppl2.internal;
///
/// S(...)
///    Variable _temp
///    ValueOf
///       Dot
///          _temp
///          Call new
///             this*
///
/// S*(...)
///       Dot
///          TypeExpr (S*)
///          Call new
///             calloc
///
final class Constructor : Expression {
    Type type;      /// Define (later resolved to NamedStruct) or NamedStruct

    override bool isResolved() { return type.isKnown; }
    override bool isConst() { return false; }
    override int priority() const { return 15; }
    override NodeID id() const { return NodeID.CONSTRUCTOR; }
    override Type getType() { return type; }

    string getName() {
        return type.isNamedStruct ? type.getNamedStruct.name : type.getDefine.name;
    }
    bool isPtr()     { return type.isPtr; }

    Expression expr() {
        if(type.isPtr) {
            return children[0].as!Expression;
        }
        return children[1].as!Expression;
    }

    override string toString() {
        return "Constructor %s%s".format(getName(), isPtr ? "*":"");
    }
}