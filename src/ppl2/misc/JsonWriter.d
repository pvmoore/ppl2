module ppl2.misc.JsonWriter;

import ppl2.internal;
import std.json;

final class JsonWriter {

    static string toString(Module m) {

        auto w = new JsonWriter;
        JSONValue v;
        w.recurse(m, v);

        return v.toJSON(true, JSONOptions.none);
    }
    void visit(Call n, ref JSONValue v) {
        v["name"]   = n.name;
    }
    void visit(Function n, ref JSONValue v) {
        v["name"]   = n.name;
    }
    void visit(Module n, ref JSONValue v) {
        v["name"]   = n.canonicalName;
        v["refs"]   = n.numRefs;
    }
    void visit(LiteralNumber n, ref JSONValue v) {
        v["value"]  = n.value.getString;
        v["type"]   = toJson(n.type);
    }
    void visit(Struct n, ref JSONValue v) {
        v["name"]   = n.name;
        v["access"] = toJson(n.access);
        v["refs"]   = n.numRefs;
    }
    void visit(Variable n, ref JSONValue v) {
        v["name"]   = n.name;
        v["type"]   = toJson(n.type);
        v["access"] = toJson(n.access);
        v["refs"]   = n.numRefs;
        if(n.isStatic) v["static"] = true;
        if(n.isConst) v["const"]  = true;
    }
private:
    void recurse(ASTNode n, ref JSONValue v) {

        v["id"] = "%s".format(n.id());

        dynamicDispatch!("visit",ASTNode)(n, this, (it) {
            writefln("visit function missing: visit(%s)".format(typeid(n)));
        }, v);

        if(!n.hasChildren) return;

        JSONValue[] vals;

        foreach(ch; n.children) {
            JSONValue c;
            recurse(ch, c);
            vals ~= c;
        }
        v["children"] = vals;
    }
    JSONValue toJson(Access a) {
        return JSONValue("%s".format(a));
    }
    JSONValue toJson(Type n) {
        if(n.isPtr) {
            auto v = toJson(n.as!Pointer.decoratedType);
            v["ptr_depth"] = n.as!Pointer.getPtrDepth();
            return v;
        } else if(n.isAlias) {
            return JSONValue(["id" : "ALIAS"]);
        } else if(n.isBasicType) {
            return JSONValue(["id" : g_typeToString[n.as!BasicType.type] ]);
        } else if(n.isTuple) {
            return JSONValue(["id" : "TUPLE"]);
        } else if(n.isStruct) {
            auto ns = n.as!Struct;
            return JSONValue(["id"   : "STRUCT",
                              "name" : ns.name ]);
        } else if(n.isFunction) {
            return JSONValue(["id" : "FUNCTION"]);
        } else if(n.isArray) {
            return JSONValue(["id" : "ARRAY"]);
        }
        assert(n.isUnknown);
        return JSONValue(["id" : "UNKNOWN"]);
    }
}
