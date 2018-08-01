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

    string msg = "Expecting an overloadable operator";
    if(t.type==TT.BOOL_EQ || t.type==TT.LANGLE || t.type==TT.RANGLE || t.type==TT.LTE || t.type==TT.GTE) {
        msg ~= ". Did you mean operator<> ?";
    }

    errorBadSyntax(t, msg);
    assert(false);
}
bool isOperatorOverloadableType(Tokens t, int offset, ref int endOffset) {
    if(t.peek(offset).value=="neg") {
        endOffset = offset+1;
        return true;
    }

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

        case TT.COMPARE:

        case TT.COLON:
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
///
/// "<" param { "," param } ">"
///
bool isTemplateParams(Tokens t, int offset, ref int endOffset) {
    assert(t.peek(offset).type==TT.LANGLE);

    bool result = false;
    t.markPosition();
    int startOffset = t.index;
    t.next(offset);
    outer:while(!result) {
        /// <
        if(t.type!=TT.LANGLE) break;
        t.next;

        /// param
        if(t.type!=TT.IDENTIFIER) break;
        t.next;

        while(t.type!=TT.RANGLE) {
            /// ,
            if(t.type!=TT.COMMA) break outer;
            t.next;

            /// param
            if(t.type!=TT.IDENTIFIER) break outer;
            t.next;
        }

        /// >
        if(t.type!=TT.RANGLE) break;

        result = true;
    }
    endOffset = t.index - startOffset;
    t.resetToMark();
    return result;
}