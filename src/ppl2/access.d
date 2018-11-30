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

Access getAccess(ASTNode n) {
    switch(n.id) with(NodeID) {
        case STRUCT:
            return n.as!Struct.access;
        case ALIAS:
            return n.as!Alias.access;
        case ENUM:
            return n.as!Enum.access;
        default:
            assert(false, "implement me %s".format(n.id));
    }
}