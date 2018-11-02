module ppl2.error.CompilationAborted;

import ppl2.internal;

final class CompilationAborted : Exception {
public:
    enum Reason {
        MAX_ERRORS_REACHED,
        COULD_NOT_CONTINUE
    }
    Reason reason;

    this(Reason reason) {
        super("");
        this.reason = reason;
    }
}