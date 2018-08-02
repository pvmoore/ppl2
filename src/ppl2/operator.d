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
    NOTHING  = Op(0, 0,null),

    /// As    = 1
    /// Dot   = 1
    /// Index = 1

    INDEX    = Op(1, 1, ":"),

    /// Call  = 2

    NEG      = Op(2, 3, " neg"),    /// the space in the value is important
    BIT_NOT  = Op(3, 3, "~"),
    BOOL_NOT = Op(4, 3, "not"),

    /// & addressof = 3
    /// @ valueof   = 3

    DIV      = Op(5, 4, "/"),
    MUL      = Op(6, 4, "*"),
    MOD      = Op(7, 4, "%"),

    ADD      = Op(8,  5, "+"),
    SUB      = Op(9,  5, "-"),
    SHL      = Op(10, 5, "<<"),
    SHR      = Op(11, 5, ">>"),
    USHR     = Op(12, 5, ">>>"),
    BIT_AND  = Op(13, 5, "&"),
    BIT_XOR  = Op(14, 5, "^"),
    BIT_OR   = Op(15, 5, "|"),

    LT       = Op(16, 7, "<"),
    GT       = Op(17, 7, ">"),
    LTE      = Op(18, 7, "<="),
    GTE      = Op(19, 7, ">="),
    BOOL_EQ  = Op(20, 7, "=="),
    COMPARE  = Op(21, 7, "<>"),     /// BOOL_NE

    /// Is = 7

    BOOL_AND = Op(22, 11, "and"),
    BOOL_OR  = Op(23, 11, "or"),

    ADD_ASSIGN     = Op(24, 14, "+="),
    SUB_ASSIGN     = Op(25, 14, "-="),
    MUL_ASSIGN     = Op(26, 14, "*="),
    DIV_ASSIGN     = Op(27, 14, "/="),
    MOD_ASSIGN     = Op(28, 14, "%="),
    BIT_AND_ASSIGN = Op(29, 14, "&="),
    BIT_XOR_ASSIGN = Op(30, 14, "^="),
    BIT_OR_ASSIGN  = Op(31, 14, "|="),

    SHL_ASSIGN     = Op(32, 14, "<<="),
    SHR_ASSIGN     = Op(33, 14, ">>="),
    USHR_ASSIGN    = Op(34, 14, ">>>="),
    ASSIGN         = Op(35, 14, "=")
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

        case INDEX.id:
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