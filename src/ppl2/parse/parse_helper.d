module ppl2.parse.parse_helper;

import ppl2.internal;

///
/// "operator" [+-*/%]=? "=" {"
///
bool isOperatorOverloadFunction(Tokens t) {
    assert(t.value=="operator");

    int end;
    if(isOperatorOverloadableType(t, 1, end)) {
        return t.peek(end+1).type==TT.LCURLY;
    }

    t.next;
    errorBadSyntax(t, "Expecting an overloadable operator");
    assert(false);
}
bool isOperatorOverloadableType(Tokens t, int offset, ref int endOffset) {
    switch(t.peek(offset).type) {
        case TT.PLUS:
        case TT.MINUS:
        case TT.ASTERISK:
        case TT.DIV:
        case TT.PERCENT:
        case TT.ADD_ASSIGN:
        case TT.SUB_ASSIGN:
        case TT.MUL_ASSIGN:
        case TT.DIV_ASSIGN:
        case TT.MOD_ASSIGN:
        case TT.SHL:
        case TT.SHL_ASSIGN:
        case TT.SHR_ASSIGN:
        case TT.USHR_ASSIGN:

        case TT.PIPE:
        case TT.AMPERSAND:
        case TT.HAT:
        case TT.BIT_OR_ASSIGN:
        case TT.BIT_AND_ASSIGN:
        case TT.BIT_XOR_ASSIGN:

        case TT.BOOL_EQ:
        case TT.BOOL_NE:
            endOffset = offset+1;
            return true;
        case TT.RANGLE: // SHR, USHR
            if(t.peek(offset+1).type==TT.RANGLE && t.peek(offset+2).type==TT.RANGLE) {
                /// >>>
                endOffset = offset+3;
            } else if(t.peek(offset+1).type==TT.RANGLE) {
                /// >>
                endOffset = offset+2;
            } else {
                /// >
                endOffset = offset+1;
            }
            return true;
        default:
            endOffset = offset;
            return false;
    }
}