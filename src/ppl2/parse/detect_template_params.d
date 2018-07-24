module ppl2.parse.detect_template_params;

import ppl2.internal;

///
/// "<" param { "," param } ">"
///
bool isTemplateParams(Tokens t, int offset) {
    bool result = false;
    t.markPosition();
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
    t.resetToMark();
    return result;
}