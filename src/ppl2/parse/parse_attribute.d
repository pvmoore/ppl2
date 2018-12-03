module ppl2.parse.parse_attribute;

import ppl2.internal;

final class AttributeParser {
private:
    Module module_;
public:
    this(Module m) {
        this.module_ = m;
    }
    void parse(Tokens t, ASTNode parent) {
        /// @
        t.skip(TT.AT);

        string name = t.value;
        t.next;

        switch(name) {
            case "inline":
                parseInlineAttribute(t);
                break;
            case "module":
                parseModuleAttribute(t);
                break;
            default:
                t.prev;
                errorBadSyntax(module_, t, "Unknown attribute '%s'".format(name));
                break;
        }
    }
private:
    /// @inline(true)
    /// @inline(false)
    void parseInlineAttribute(Tokens t) {
        auto a = new InlineAttribute;

        string value = getValueProperty(t);
        a.value = "true"==value;

        t.addAttribute(a);
    }
    void parseModuleAttribute(Tokens t) {
        import std.array : replace;

        auto a = new ModuleAttribute;

        /// Add this attribute to the current module directly
        module_.attributes ~= a;

        foreach(k,v; getNameValueProperties(t, "module", ["priority"])) {
            if(k=="priority") {
                a.priority = v.replace("_","").to!int;
            }
        }
    }
    string getValueProperty(Tokens t) {
        /// (
        t.skip(TT.LBRACKET);

        string value = t.value;
        t.next;

        /// )
        t.skip(TT.RBRACKET);

        return value;
    }
    string[string] getNameValueProperties(Tokens t, string name, string[] keys) {
        string[string] props;

        import common : contains;

        /// (
        t.skip(TT.LBRACKET);

        /// priority
        while(t.type!=TT.RBRACKET) {
            string prop = t.value;
            if(!keys.contains(prop)) {
                module_.addError(t, "Unknown @%s property '%s'".format(name, prop), true);
            }
            t.next;

            t.skip(TT.EQUALS);

            props[prop] = t.value;
            t.next;

            t.expect(TT.COMMA, TT.RBRACKET);
            if(t.type==TT.COMMA) t.next;
        }

        /// )
        t.skip(TT.RBRACKET);

        return props;
    }
}