module ppl2.access;

import ppl2.internal;

enum Access {
    PUBLIC,
    PRIVATE,
    READONLY
}

string toString(Access a) {
    return "%s".format(a).toLower;
}