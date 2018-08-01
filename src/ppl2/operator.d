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
        case "neg": return Operator.NEG;
        default: break;
    }
    return Operator.NOTHING;
}
struct Op {
    int id;
    int priority;
    string value;
}
enum Operator : Op {
    NOTHING = Op(0,0,null),

    NEG      = Op(1, 2, " neg"),    /// the space in the value is important
    BIT_NOT  = Op(2, 2, "~"),
    BOOL_NOT = Op(3, 2, "not"),

    /// & addressof = 2
    /// @ valueof   = 2

    DIV      = Op(4, 3, "/"),
    MUL      = Op(5, 3, "*"),
    MOD      = Op(6, 3, "%"),

    ADD      = Op(7,  4, "+"),
    SUB      = Op(8,  4, "-"),
    SHL      = Op(9,  4, "<<"),
    SHR      = Op(10, 4, ">>"),
    USHR     = Op(11, 4, ">>>"),
    BIT_AND  = Op(12, 4, "&"),
    BIT_XOR  = Op(13, 4, "^"),
    BIT_OR   = Op(14, 4, "|"),

    LT       = Op(15, 7, "<"),
    GT       = Op(16, 7, ">"),
    LTE      = Op(17, 7, "<="),
    GTE      = Op(18, 7, ">="),
    BOOL_EQ  = Op(19, 7, "=="),
    COMPARE  = Op(20, 7, "<>"),     /// BOOL_NE

    BOOL_AND = Op(21, 11, "and"),
    BOOL_OR  = Op(22, 11, "or"),

    ADD_ASSIGN     = Op(23, 14, "+="),
    SUB_ASSIGN     = Op(24, 14, "-="),
    MUL_ASSIGN     = Op(25, 14, "*="),
    DIV_ASSIGN     = Op(26, 14, "/="),
    MOD_ASSIGN     = Op(27, 14, "%="),
    BIT_AND_ASSIGN = Op(28, 14, "&="),
    BIT_XOR_ASSIGN = Op(29, 14, "^="),
    BIT_OR_ASSIGN  = Op(30, 14, "|="),

    SHL_ASSIGN     = Op(31, 14, "<<="),
    SHR_ASSIGN     = Op(32, 14, ">>="),
    USHR_ASSIGN    = Op(33, 14, ">>>="),
    ASSIGN         = Op(34, 14, "=")
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
        case COMPARE.id:
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
        case SHL.id:
        case SHR.id:
        case USHR.id:
        case BIT_OR.id:
        case BIT_AND.id:
        case BIT_XOR.id:

        case ADD_ASSIGN.id:
        case SUB_ASSIGN.id:
        case MUL_ASSIGN.id:
        case DIV_ASSIGN.id:
        case MOD_ASSIGN.id:
        case SHL_ASSIGN.id:
        case SHR_ASSIGN.id:
        case USHR_ASSIGN.id:
        case BIT_OR_ASSIGN.id:
        case BIT_AND_ASSIGN.id:
        case BIT_XOR_ASSIGN.id:

        case BOOL_EQ.id:
        case COMPARE.id:

        case NEG.id:
            return true;
        default:
            return false;
    }
}
bool isComparison(Operator o) {
    switch(o.id) with(Operator) {
        case LT.id:
        case LTE.id:
        case GT.id:
        case GTE.id:
        case BOOL_EQ.id:
        case COMPARE.id:
            return true;
        default:
            return false;
    }
}