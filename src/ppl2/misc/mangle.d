module ppl2.misc.mangle;

import ppl2.internal;

string mangle(Function f) {
    if(f.isExtern) return f.name;
    if(f.args.numArgs==0) return f.name;
    return "%s(%s)".format(f.name, mangle(f.args.argTypes()));
}
string mangle(Type t) {
    string s;
    final switch(t.getEnum) with(Type) {
        case UNKNOWN: assert(false, "mangle - type is UNKNOWN");
        case BOOL:   s = "B"; break;
        case BYTE:   s = "b"; break;
        case SHORT:  s = "s"; break;
        case INT:    s = "i"; break;
        case LONG:   s = "l"; break;
        case HALF:   s = "h"; break;
        case FLOAT:  s = "f"; break;
        case DOUBLE: s = "d"; break;
        case VOID:   s = "v"; break;
        case NAMED_STRUCT:
            auto n = t.getNamedStruct;
            s = "N[%s]".format(n.name);
            break;
        case ANON_STRUCT:
            auto st = t.getAnonStruct;
            s = "n[%s]".format(mangle(st.memberVariableTypes()));
            break;
        case FUNCTION:
            auto f = t.getFunctionType;
            s = "F[%s]".format(mangle(f.argTypes));
            break;
        case ARRAY:
            auto a = t.getArrayType;
            s = "A[%s]".format(mangle(a.subtype));
            break;
    }
    for(auto i=0;i<t.getPtrDepth(); i++) {
        s ~= "*";
    }
    return s;
}
string mangle(Type[] types) {
    auto buf = new StringBuffer;
    foreach(t; types) {
        buf.add(mangle(t));
    }
    return buf.toString();
}
