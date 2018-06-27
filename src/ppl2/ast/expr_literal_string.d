module ppl2.ast.expr_literal_string;

import ppl2.internal;
///
/// string ::= prefix '"' text '"'
/// prefix ::= nothing | "r" | "u8"
///
/// r  - raw string with no escapes eg. r"\bregex\w"
/// u8 - utf8 string (logical length may be different to physical length)
///
final class LiteralString : Expression {
    enum Encoding { U8, RAW }

    ArrayType type;
    string value;
    Encoding enc;

    this() {
        type         = makeNode!ArrayType(this);
        type.subtype = TYPE_BYTE;

        enc  = Encoding.U8;
    }

    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.LITERAL_STRING; }
    override int priority() const { return 15; }
    override Type getType() { return type; }

    ///
    /// Fixme. These counts are probably wrong.
    ///
    int calculateLength() {
        final switch(enc) with(Encoding) {
            case U8:  return value.length.as!int;
            case RAW: return value.length.as!int;
        }
    }

    override string toString() {
        string e = enc==Encoding.RAW ? "r" : "";
        return "%s\"%s\" (type=%s)".format(e, value, type);
    }
}