module ppl2.misc.mangle;

import ppl2.internal;

string mangle(NamedStruct ns) {
    string name = ns.name;
    int i = 2;
    string prefix = name;

    while(g_uniqueStructNames.contains(name)) {
        name = "%s%s".format(prefix, i);
        i++;
    }
    g_uniqueStructNames.add(name);
    return name;
}
string mangle(Function f) {
    if(f.isExtern || f.isProgramEntry) return f.name;

    string name  = f.name;
    auto struct_ = f.getContainingStruct();
    if(struct_ && struct_.isNamed) {
        name = struct_.getName ~ "." ~ name;
    }

    if(f.params().numParams>0) {
        name ~= "(%s)".format(mangle(f.params().paramTypes()));
    }
    if(!g_uniqueFunctionNames.contains(name)) {
        g_uniqueFunctionNames.add(name);
        return name;
    }

    name = f.getModule().canonicalName ~ "::" ~ name;

    int i = 2;
    string prefix = name;
    while(g_uniqueFunctionNames.contains(name)) {
        name = "%s%s".format(prefix, i);
        i++;
    }
    g_uniqueFunctionNames.add(name);
    return name;
}
string mangle(Type t) {
    string s;
    if(t.isDefine) {
        s = t.getDefine.name;
    } else {
        final switch (t.getEnum) with(Type) {
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
                s = "N[%s]".format(n.getUniqueName());
                break;
            case ANON_STRUCT:
                auto st = t.getAnonStruct;
                s = "n[%s]".format(mangle(st.memberVariableTypes()));
                break;
            case FUNCTION:
                auto f = t.getFunctionType;
                s = "F[%s]".format(mangle(f.paramTypes));
                break;
            case ARRAY:
                auto a = t.getArrayType;
                s = "A[%s]".format(mangle(a.subtype));
                break;
        }
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
