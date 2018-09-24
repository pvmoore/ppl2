module ppl2.parse.parse_variable;

import ppl2.internal;

final class VariableParser {
private:
    Module module_;

    ExpressionParser exprParser() { return module_.exprParser; }
    TypeParser typeParser() { return module_.typeParser; }
    TypeDetector typeDetector() { return module_.typeDetector; }
    NodeBuilder builder() { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
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

        v.moduleNID = module_.nid;

        if("const"==t.value) {
            t.next;
            v.isConst = true;
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
                errorMissingType(t, t.value);
            }
            if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.IDENTIFIER) {
                errorMissingType(t, t.value);
            }

            v.type = TYPE_UNKNOWN;
        }

        if(t.type==TT.IDENTIFIER && !t.get.templateType) {
            v.name = t.value;
            if(v.name=="this") {
                throw new CompilerError(t,
                    "'this' is a reserved word");
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
                    throw new CompilerError(v,
                        "Implicitly typed variable requires initialisation");
                }
                if(v.isConst) {
                    throw new CompilerError(v,
                        "Const variable must be initialised");
                }
            }
        }
    }
}