module ppl2.misc.mangle;

import ppl2.internal;

string mangle(NamedStruct ns) {
    string name = ns.name;
    if(g_uniqueStructNames.contains(name)) {
        name = ns.moduleName ~ "." ~ name;
    }

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
    if(f.isStructMember) {
        auto struct_ = f.getAncestor!AnonStruct();
        if(struct_.isNamed) {
            name = struct_.parent.as!NamedStruct.getUniqueName ~ "." ~ name;
        }
    }

    string params;
    if(f.params().numParams>0) {
        params = "(%s)".format(mangle(f.params().paramTypes()));
    }

    if(g_uniqueFunctionNames.contains(name ~ params)) {
        if(f.isGlobal) name = f.moduleName ~ "::" ~ name;
    }

    name ~= params;

    if(!g_uniqueFunctionNames.contains(name)) {
        g_uniqueFunctionNames.add(name);
        return name;
    }

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
    final switch (t.getEnum) with(Type) {
        case UNKNOWN: assert(false, "type must be known");
        case BOOL:   s = "o"; break;
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
            s = "[%s]".format(mangle(st.memberVariableTypes()));
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
