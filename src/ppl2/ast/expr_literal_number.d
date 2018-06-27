module ppl2.ast.expr_literal_number;

import ppl2.internal;

final class LiteralNumber : Expression {
    Type type;
    string str;
    Value value;

    this() {
        type = TYPE_UNKNOWN;
    }

    static LiteralNumber makeConst(long num, Type t=TYPE_UNKNOWN) {
        auto lit = makeNode!LiteralNumber;
        lit.str  = num.to!string;
        lit.type = t;
        if(t.isUnknown) {
            lit.determineType();
        } else {
           lit. value = Value(lit);
        }
        return lit;
    }
    LiteralNumber copy() {
        auto c   = makeNode!LiteralNumber(this);
        c.line   = line;
        c.column = column;
        c.str    = str;
        c.type   = type;
        c.value  = Value(c);
        return c;
    }
    override bool isResolved() { return type.isKnown; }
    override bool isConst() { return true; }
    override int priority() const { return 15; }
    override Type getType() { return type; }
    override NodeID id() const { return NodeID.LITERAL_NUMBER; }

    void determineType() {
        Tuple!(Type,string) r = parseNumberLiteral(str);
        type   = r[0];
        str    = r[1];
        value  = Value(this);
    }
    override string toString() {
        return "%s (type=const %s)".format(value.lit && value.type && value.type.isKnown ? value.getString() : str, type);
    }
}
//============================================================================================
struct Value {
    union {
        double f;
        long i;
    }
    LiteralNumber lit;

    this(LiteralNumber lit) {
        assert(lit);
        this.lit = lit;
        if(type().isInteger || type().isBool) {
            i = lit.str.to!long;
        } else if(type().isReal) {
            f = lit.str.to!double;
        } else assert(false, "How did we get here? type is %s".format(type()));
    }
    Type type()        { return lit.type; }
    bool getBool()     { return getLong() != FALSE; }
    int getInt()       { return cast(int)getLong(); }
    long getLong()     { if(type.isReal) return cast(long)f; return i; }
    double getDouble() { if(!type.isReal) return cast(double)i; return f; }
    string getString() { return type.isReal ? "%f".format(f) : "%s".format(i); }

    void applyUnary(Operator op) {
        switch(op.id) with(Operator) {
            case BOOL_NOT.id: i = !getBool(); break;
            case BIT_NOT.id:  i = ~getLong(); break;
            case NEG.id:
                if(type.isReal) {
                    f = -getDouble();
                } else {
                    i = -getLong();
                }
                break;
            default: assert(false, "Shouldn't get here");
        }
    }

    void applyBinary(Type t, Operator op, Value right) {
        if(t.isInteger || t.isBool) {
            switch(op.id) with(Operator) {
                case DIV.id: i = i / right.getLong(); break;
                case MUL.id: i = i * right.getLong(); break;
                case MOD.id: i = i % right.getLong(); break;
                case ADD.id: i = i + right.getLong(); break;
                case SUB.id: i = i - right.getLong(); break;

                case SHL.id:  i  = cast(long)i << right.getLong(); break;
                case SHR.id:
                    /// special case
                    switch(type.getEnum) with(Type) {
                        case BYTE:  i = cast(byte) (i|0xffffffff_ffffff00) >> right.getInt(); break;
                        case SHORT: i = cast(short)(i|0xffffffff_ffff0000) >> right.getInt(); break;
                        case INT:   i = cast(long) (i|0xffffffff_00000000) >> right.getInt(); break;
                        default:    i = cast(long)i >> right.getInt(); break;
                    }
                    break;
                case USHR.id: i = cast(ulong)i >>> right.getLong(); break;

                case LT.id:      i = (i < right.getLong())  ? TRUE : FALSE; break;
                case GT.id:      i = (i > right.getLong())  ? TRUE : FALSE; break;
                case LTE.id:     i = (i <= right.getLong()) ? TRUE : FALSE; break;
                case GTE.id:     i = (i >= right.getLong()) ? TRUE : FALSE; break;
                case BOOL_EQ.id: i = (i == right.getLong()) ? TRUE : FALSE; break;
                case BOOL_NE.id: i = (i != right.getLong()) ? TRUE : FALSE; break;

                case BIT_AND.id: i = i & right.getLong(); break;
                case BIT_XOR.id: i = i ^ right.getLong(); break;
                case BIT_OR.id:  i = i | right.getLong(); break;

                case BOOL_AND.id: i = getBool() && right.getBool(); break;
                case BOOL_OR.id:  i = getBool() || right.getBool(); break;

                default: assert(false, "How did we get here? %s".format(op));
            }
        } else {
            switch (op.id) with(Operator) {
                case DIV.id: f = f / right.getDouble(); break;
                case MUL.id: f = f * right.getDouble(); break;
                case MOD.id: f = f % right.getDouble(); break;
                case ADD.id: f = f + right.getDouble(); break;
                case SUB.id: f = f - right.getDouble(); break;

                case SHL.id:  f = getLong() << right.getLong(); break;
                case SHR.id:
                    /// special case
                    switch(type.getEnum) with(Type) {
                        case BYTE:  f = cast(byte) (getLong()|0xffffffff_ffffff00) >> right.getInt(); break;
                        case SHORT: f = cast(short)(getLong()|0xffffffff_ffff0000) >> right.getInt(); break;
                        case INT:   f = cast(long) (getLong()|0xffffffff_00000000) >> right.getInt(); break;
                        default:    f = cast(long)getLong() >> right.getInt(); break;
                    }
                    break;
                case USHR.id: f = cast(ulong)getLong() >>> right.getLong(); break;

                case LT.id:      f = (f < right.getDouble())  ? TRUE : FALSE; break;
                case GT.id:      f = (f > right.getDouble())  ? TRUE : FALSE; break;
                case LTE.id:     f = (f <= right.getDouble()) ? TRUE : FALSE; break;
                case GTE.id:     f = (f >= right.getDouble()) ? TRUE : FALSE; break;
                case BOOL_EQ.id: f = (f == right.getDouble()) ? TRUE : FALSE; break;
                case BOOL_NE.id: f = (f != right.getDouble()) ? TRUE : FALSE; break;

                case BIT_AND.id: f = (cast(ulong)getLong() & right.getLong()); break;
                case BIT_XOR.id: f = (cast(ulong)getLong() ^ right.getLong()); break;
                case BIT_OR.id:  f = (cast(ulong)getLong() | right.getLong()); break;

                case BOOL_AND.id: i = getBool() && right.getBool(); break;
                case BOOL_OR.id:  i = getBool() || right.getBool(); break;

                default: assert(false, "How did we get here?");
            }
        }
        lit.type = t;
    }
    void as(Type t) {
        switch(t.getEnum) with(Type) {
            case BOOL:  i = cast(uint)getLong() == 0 ? FALSE : TRUE; break;
            case BYTE:  i = cast(ubyte)getLong(); break;
            case SHORT: i = cast(ushort)getLong(); break;
            case INT:   i = cast(uint)getLong(); break;
            case LONG:  i = cast(ulong)getLong(); break;
            case HALF:
            case FLOAT:
            case DOUBLE: f = getDouble(); break;
            default:
                assert(false, "How did we get here?");
        }
        lit.type = t;
    }
}
