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
    void parse(TokenNavigator t, ASTNode parent, bool requireType=false) {
        //dd("variable");
        auto v = makeNode!Variable(t);
        parent.addToEnd(v);

        if("const"==t.value) {
            t.next;
            v.isConst = true;
        }

        if(t.isKeyword("var")) {
            v.isImplicit = true;
        }

        if(typeDetector().isType(t, v)) {
            v.type = typeParser.parse(t, v);

            if(v.type.isFunction) {
                /// Make this a pointer
                v.type = PtrType.of(v.type, 1);
            }
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

        if(t.type==TT.IDENTIFIER) {
            v.name = t.value;
            if(v.name=="this") {
                throw new CompilerError(Err.VAR_CAN_NOT_BE_CALLED_THIS, t,
                    "'this' is a reserved word");
            }
            t.next;

            /// initialiser
            if(t.type == TT.EQUALS) {
                t.next;

                auto ini = makeNode!Initialiser(t);
                ini.var = v;
                v.addToEnd(ini);

                exprParser().parse(t, ini);

            } else {
                if(v.isImplicit) {
                    throw new CompilerError(Err.VAR_WITHOUT_INITIALISER, v,
                        "Implicitly typed variable requires initialisation");
                }
                if(v.isConst) {
                    throw new CompilerError(Err.CONST_VAR_WITHOUT_INITIALISER, v,
                        "Const variable must be initialised");
                }
            }
        } else if(t.type==TT.COMMA) {
            t.next;
        }
    }
}