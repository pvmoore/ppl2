module ppl2.operator;

import ppl2.internal;

Operator parseOperator(Tokens t) {
    /// '>' is tokenised to separate tokens to ease parsing of nested parameterised templates.
    /// Account for this here:
    if(t.type==TT.RANGLE) {
        if(t.peek(1).type==TT.RANGLE) {
            if(t.peek(2).type==TT.RANGLE) {
                t.next(2);
                return Operator.USHR;
            }
            t.next;
            return Operator.SHR;
        }
    }
    auto p = t.type in g_ttToOperator;
    if(p) return *p;
    switch(t.value) {
        case "and": return Operator.BOOL_AND;
        case "or":  return Operator.BOOL_OR;
        default: break;
    }
    return Operator.NOTHING;
}
///
/// & (AddressOf) = 2
/// @ (ValueOf)   = 2
///
struct Op {
    int id;
    int priority;
    string value;
}
enum Operator : Op {
    NOTHING = Op(0,0,null),

    NEG      = Op(0, 2, "neg"),
    BIT_NOT  = Op(1, 2, "~"),
    BOOL_NOT = Op(2, 2, "not"),

    DIV  = Op(3, 3, "/"),
    MUL = Op(5, 3, "*"),
    MOD  = Op(6, 3, "%"),

    ADD = Op(8, 4, "+"),
    SUB = Op(9, 4, "-"),

    SHL  = Op(10, 5, "<<"),
    SHR  = Op(11, 5, ">>"),
    USHR = Op(12, 5, ">>>"),

    LT   = Op(13, 6, "<"),
    GT   = Op(14, 6, ">"),
    LTE  = Op(15, 6, "<="),
    GTE  = Op(16, 6, ">="),

    BOOL_EQ = Op(21, 7, "=="),
    BOOL_NE = Op(22, 7, "!="),

    BIT_AND = Op(23, 8, "&"),
    BIT_XOR = Op(24, 9, "^"),
    BIT_OR  = Op(25, 10, "|"),

    BOOL_AND = Op(26, 11, "and"),
    BOOL_OR  = Op(27, 11, "or"),

    ADD_ASSIGN     = Op(28, 14, "+="),
    SUB_ASSIGN     = Op(29, 14, "-="),
    MUL_ASSIGN     = Op(30, 14, "*="),
    DIV_ASSIGN     = Op(31, 14, "/="),
    MOD_ASSIGN     = Op(33, 14, "%="),
    BIT_AND_ASSIGN = Op(35, 14, "&="),
    BIT_XOR_ASSIGN = Op(36, 14, "^="),
    BIT_OR_ASSIGN  = Op(37, 14, "|="),

    SHL_ASSIGN     = Op(38, 14, "<<="),
    SHR_ASSIGN     = Op(39, 14, ">>="),
    USHR_ASSIGN    = Op(40, 14, ">>>="),
    ASSIGN         = Op(41, 14, "=")
}
//===========================================================================
bool isAssign(Operator o) {
    return o.id >= Operator.ADD_ASSIGN.id && o.id <= Operator.ASSIGN.id;
}
bool isBool(Operator o) {
    switch(o.id) with(Operator) {
        case BOOL_AND.id:
        case BOOL_OR.id:
        case BOOL_NOT.id:
        case BOOL_EQ.id:
        case BOOL_NE.id:
        case LT.id:
        case GT.id:
        case LTE.id:
        case GTE.id:
            return true;
        default:
            return false;
    }
}
bool isUnary(Operator o) {
    switch(o.id) with(Operator) {
        case NEG.id:
        case BIT_NOT.id:
        case BOOL_NOT.id:
            return true;
        default:
            return false;
    }
}
bool isOverloadable(Operator o) {
    switch(o.id) with(Operator) {
        case ADD.id:
        case SUB.id:
        case MUL.id:
        case DIV.id:
        case MOD.id:
        case ADD_ASSIGN.id:
        case SUB_ASSIGN.id:
        case MUL_ASSIGN.id:
        case DIV_ASSIGN.id:
        case MOD_ASSIGN.id:
            return true;
        default:
            return false;
    }
}