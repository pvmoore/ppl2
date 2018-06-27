module ppl2.interfaces.callable;

import ppl2.internal;
///
/// Function, Variable
///
interface Callable {
    string getName();
    Type getType();
}
//============================================================================
bool areKnown(Array!Callable array) {
    if(array.length==0) return true;

    foreach(c; array[]) {
        if(c.getType().isUnknown) return false;
    }
    return true;
}