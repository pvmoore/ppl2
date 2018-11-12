module ppl2.Mangler;

import ppl2.internal;

final class Mangler {
private:
    //Set!string uniqueFunctionNames;
    //Set!string uniqueStructAndModuleNames;
public:
    this() {
        //this.uniqueFunctionNames        = new Set!string;
        //this.uniqueStructAndModuleNames = new Set!string;
    }
    void clearState() {
        //uniqueFunctionNames.clear();
        //uniqueStructAndModuleNames.clear();
    }
    void addUniqueModuleName(string canonicalName) {
        string name = canonicalName;
        auto i      = canonicalName.lastIndexOf("::");
        if(i!=-1) name = canonicalName[i+2..$];
        //uniqueStructAndModuleNames.add(name);
    }
    string mangle(NamedStruct ns) {
        string name = ns.name;
        //int i = 2;
        //string prefix = name;
        //while(uniqueStructAndModuleNames.contains(name)) {
        //    name = "%s_%s".format(prefix, i);
        //    i++;
        //}
        //uniqueStructAndModuleNames.add(name);
        return name;
    }
    string mangle(Function f) {
        if(f.isExtern || f.isProgramEntry) return f.name;

        string name  = f.name;

        if(f.isStructMember) {
            auto struct_ = f.getAncestor!AnonStruct();
            if(struct_.isNamedStruct) {
                string sep = ".";
                if(f.isStatic) sep = "::";
                name = struct_.as!NamedStruct.getUniqueName ~ sep ~ name;
            }
        } else {
            auto m = f.getModule;
            name = m.canonicalName ~ "::" ~ name;
        }

        string params;
        if(f.params().numParams>0) {
            params = "(%s)".format(mangle(f.params().paramTypes()));
        }

        name ~= params;

        //if(!uniqueFunctionNames.contains(name)) {
        //    uniqueFunctionNames.add(name);
        //    return name;
        //}
        //
        //int i = 2;
        //string prefix = name;
        //while(uniqueFunctionNames.contains(name)) {
        //    name = "%s_%s".format(prefix, i);
        //    i++;
        //}
        //uniqueFunctionNames.add(name);
        return name;
    }
    string mangle(Type t) {
        assert(t.isKnown);

        return "%s".format(t);

        //string s;
        //final switch (t.getEnum) with(Type) {
        //    case UNKNOWN: assert(false, "type must be known");
        //    case BOOL:   s = "o"; break;
        //    case BYTE:   s = "b"; break;
        //    case SHORT:  s = "s"; break;
        //    case INT:    s = "i"; break;
        //    case LONG:   s = "l"; break;
        //    case HALF:   s = "h"; break;
        //    case FLOAT:  s = "f"; break;
        //    case DOUBLE: s = "d"; break;
        //    case VOID:   s = "v"; break;
        //    case NAMED_STRUCT:
        //        auto n = t.getNamedStruct;
        //        s = "N[%s]".format(n.getUniqueName());
        //        break;
        //    case ANON_STRUCT:
        //        auto st = t.getAnonStruct;
        //        s = "[%s]".format(mangle(st.memberVariableTypes()));
        //        break;
        //    case ARRAY:
        //        auto a = t.getArrayType;
        //        s = "A[%s]".format(mangle(a.subtype));
        //        break;
        //    case FUNCTION:
        //        auto f = t.getFunctionType;
        //        s = "F[%s]".format(mangle(f.paramTypes));
        //        break;
        //}
        //for(auto i=0;i<t.getPtrDepth(); i++) {
        //    s ~= "*";
        //}
        //return s;
    }
    string mangle(Type[] types) {
        auto buf = new StringBuffer;
        foreach(i, t; types) {
            if(i>0) buf.add(",");
            buf.add(mangle(t));
        }
        return buf.toString();
    }
}
