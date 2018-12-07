module ppl2.Operator;

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
    if(t.type==TT.LSQBRACKET) {
        if(t.peek(1).type==TT.RSQBRACKET) {
            t.next;
            return Operator.INDEX;
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

    /// Dot   = 2
    /// Index = 2

    INDEX    = Op(1, 2, "[]"),

    /// Call        = 2
    /// BuiltinFunc = 2

    /// As    = 3

    NEG      = Op(2, 5, " neg"),    /// the space in the value is important
    BIT_NOT  = Op(3, 5, "~"),
    BOOL_NOT = Op(4, 5, "not"),

    /// & addressof = 3
    /// * valueof   = 3

    DIV      = Op(5, 6, "/"),
    MUL      = Op(6, 6, "*"),
    MOD      = Op(7, 6, "%"),

    ADD      = Op(8,  7, "+"),
    SUB      = Op(9,  7, "-"),
    SHL      = Op(10, 7, "<<"),
    SHR      = Op(11, 7, ">>"),
    USHR     = Op(12, 7, ">>>"),
    BIT_AND  = Op(13, 7, "&"),
    BIT_XOR  = Op(14, 7, "^"),
    BIT_OR   = Op(15, 7, "|"),

    LT       = Op(16, 9, "<"),
    GT       = Op(17, 9, ">"),
    LTE      = Op(18, 9, "<="),
    GTE      = Op(19, 9, ">="),
    BOOL_EQ  = Op(20, 9, "=="),
    COMPARE  = Op(21, 9, "<>"),     /// BOOL_NE

    /// Is = 9

    BOOL_AND = Op(22, 11, "and"),
    BOOL_OR  = Op(23, 11, "or"),

    /// assignments below here
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

    /// Calloc      = 15
    /// Closure     = 15
    /// Composite   = 15
    /// Constructor = 15
    /// Identifier  = 15
    /// If          = 15
    /// Initialiser = 15
    /// Literals    = 15
    /// ModuleAlias = 15
    /// Parenthesis = 15
    /// Select      = 15
    /// TypeExpr    = 15
}
//===========================================================================
Operator removeAssign(Operator o) {
    switch(o.id) with(Operator) {
        case ADD_ASSIGN.id:     return ADD;
        case SUB_ASSIGN.id:     return SUB;
        case MUL_ASSIGN.id:     return MUL;
        case DIV_ASSIGN.id:     return DIV;
        case MOD_ASSIGN.id:     return MOD;
        case BIT_AND_ASSIGN.id: return BIT_AND;
        case BIT_XOR_ASSIGN.id: return BIT_XOR;
        case BIT_OR_ASSIGN.id:  return BIT_OR;
        case SHL_ASSIGN.id:     return SHL;
        case SHR_ASSIGN.id:     return SHR;
        case USHR_ASSIGN.id:    return USHR;
        default:
            assert(false, "not an assign operator %s".format(o));
    }
}
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
bool isPtrArithmetic(Operator o) {
    switch(o.id) with(Operator) {
        case ADD.id:
        case SUB.id:
        case ADD_ASSIGN.id:
        case SUB_ASSIGN.id:
            return true;
        default:
            return false;
    }
}