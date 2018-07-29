module ppl2.access;

import ppl2.internal;

enum Access {
    PUBLIC,
    PRIVATE,
    READONLY
}

bool isPublic(Access a)   { return a==Access.PUBLIC; }
bool isPrivate(Access a)  { return a==Access.PRIVATE; }
bool isReadOnly(Access a) { return a==Access.READONLY; }

string toString(Access a) {
    return "%s".format(a).toLower;
}