module ppl2.parse.parse_variable;

import ppl2.internal;

final class VariableParser {
private:
    Module module_;

    auto  exprParser()  { return module_.exprParser; }
    auto typeParser()   { return module_.typeParser; }
    auto typeDetector() { return module_.typeDetector; }
    auto builder()      { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    ///
    /// Parse parameter list.
    ///
    ///            {name ->
    ///            {int value, byte* str, int base -> }
    ///  Start here ^
    void parseParameters(Tokens t, ASTNode parent) {
        auto params = makeNode!Parameters(t);


    }
    Type parseParameterForTemplate(Tokens t, ASTNode parent) {
        Type type;
        //while(t.hasNext) {
            if(typeDetector().isType(t, parent)) {
                type = typeParser.parseForTemplate(t, parent);
            }
            if(t.type==TT.COMMA) {
                assert(false);
                //t.next;
            } else {
                /// name
                assert(t.type==TT.IDENTIFIER, "type=%s".format(t.get));
                t.next;
            }
        //}
        return type;
    }
    ///
    /// type        // only inside an anonymous struct
    /// id          // only as a LiteralFunction parameter
    /// type id
    /// type id "=" expression
    ///
    void parse(Tokens t, ASTNode parent, bool requireType=false) {
        //dd("variable", t.get);
        auto v = makeNode!Variable(t);
        parent.add(v);

        /// Allow "static const" or "const static"
        if("static"==t.value) {
            t.next;
            v.isStatic = true;
        }
        if("const"==t.value) {
            t.next;
            v.isConst = true;
        }
        if("static"==t.value) {
            t.next;
            v.isStatic = true;
        }

        if(t.isKeyword("var")) {
            v.isImplicit = true;
        }

        v.access = t.access();

        if(typeDetector().isType(t, v)) {
            v.type = typeParser.parse(t, v);
        } else {
            /// there is no type
            if(requireType) {
                errorMissingType(module_, t, t.value);
            }
            if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.IDENTIFIER) {
                errorMissingType(module_, t, t.value);
            }

            v.type = TYPE_UNKNOWN;
        }

        if(t.type==TT.IDENTIFIER && !t.get.templateType) {
            v.name = t.value;
            if(v.name=="this") {
                module_.addError(t, "'this' is a reserved word", true);
            }
            t.next;

            /// initialiser
            if(t.type == TT.EQUALS) {
                t.next;

                auto ini = makeNode!Initialiser(t);
                ini.var = v;
                v.add(ini);

                exprParser().parse(t, ini);

            } else {
                if(v.isImplicit) {
                    module_.addError(v, "Implicitly typed variable requires initialisation", true);
                }
                if(v.isConst) {
                    module_.addError(v, "Const variable must be initialised", true);
                }
            }
        }

        if(v.type.isUnknown && t.type==TT.LANGLE) {
            t.prev;
            module_.addError(v, "Type %s not found".format(t.value), false);
        }
    }
}