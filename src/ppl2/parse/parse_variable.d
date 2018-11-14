module ppl2.parse.parse_variable;

import ppl2.internal;

final class VariableParser {
private:
    Module module_;

    static struct Flags {
        bool nameRequired;
        bool typeRequired;
        bool nameForbidden;
        bool staticForbidden;
    }

    auto exprParser()   { return module_.exprParser; }
    auto typeParser()   { return module_.typeParser; }
    auto typeDetector() { return module_.typeDetector; }
    auto builder()      { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    Type parseParameterForTemplate(Tokens t, ASTNode parent) {
        Type type;
        if(typeDetector().isType(t, parent)) {
            type = typeParser.parseForTemplate(t, parent);
        }

        if(t.type==TT.COMMA) {
            assert(false);
        } else {
            /// name
            assert(t.type==TT.IDENTIFIER, "type=%s".format(t.get));
            t.next;
        }
        return type;
    }
    /// foo { int a, b ->
    ///       ^^^^^  ^
    void parseParameter(Tokens t, ASTNode parent) {
        Flags flags = {
            nameRequired:  true,
            typeRequired:  false,
            nameForbidden: false,
            staticForbidden: true
        };
        parse(t, parent, flags);
    }
    /// {int a -> void}
    ///  ^^^^^
    void parseFunctionTypeParameter(Tokens t, ASTNode parent) {
        Flags flags = {
            nameRequired:  false,
            typeRequired:  true,
            nameForbidden: false,
            staticForbidden: true
        };
        parse(t, parent, flags);
    }
    /// {int a->int}
    ///         ^^^
    void parseReturnType(Tokens t, ASTNode parent) {
        Flags flags = {
            nameRequired:  false,
            typeRequired:  true,
            nameForbidden: true,
            staticForbidden: true
        };
        parse(t, parent, flags);
    }
    /// struct S { int a ...
    ///            ^^^^^
    void parseNamedStructMember(Tokens t, ASTNode parent) {
        Flags flags = {
            nameRequired:  true,
            typeRequired:  true,
            nameForbidden: false,
            staticForbidden: false
        };
        parse(t, parent, flags);
    }
    /// [int a ...
    ///  ^^^^^
    void parseAnonStructMember(Tokens t, ASTNode parent) {
        Flags flags = {
            nameRequired:  false,
            typeRequired:  true,
            nameForbidden: false,
            staticForbidden: true
        };
        parse(t, parent, flags);
    }
    /// func { var a ...
    ///        ^^^^^
    void parseLocal(Tokens t, ASTNode parent) {
        Flags flags = {
            nameRequired:  true,
            typeRequired:  true,
            nameForbidden: false,
            staticForbidden: true
        };
        parse(t, parent, flags);
    }
private:
    ///
    /// type        // only inside an anonymous struct
    /// id          // only as a LiteralFunction parameter
    /// type id
    /// type id "=" expression
    ///
    void parse(Tokens t, ASTNode parent, Flags flags) {
        //dd("variable", t.get);
        auto v = makeNode!Variable(t);
        parent.add(v);

        /// Allow "static const" or "const static"
        if("static"==t.value) {
            if(flags.staticForbidden) {
                module_.addError(t, "static not allowed here", true);
            }
            t.next;
            v.isStatic = true;
        }
        if("const"==t.value) {
            t.next;
            v.isConst    = true;
            v.isImplicit = true;
        }
        if("static"==t.value) {
            if(flags.staticForbidden) {
                module_.addError(t, "static not allowed here", true);
            }
            t.next;
            v.isStatic = true;
        }

        if(t.isKeyword("var")) {
            v.isImplicit = true;
        }

        v.access = t.access();

        /// Type
        if(typeDetector().isType(t, v)) {
            v.type = typeParser.parse(t, v);
        } else {
            /// there is no type
            if(!v.isImplicit) {
                if(flags.typeRequired) {
                    errorMissingType(module_, t, t.value);
                }
                if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.IDENTIFIER) {
                    errorMissingType(module_, t, t.value);
                }
            }

            v.type = TYPE_UNKNOWN;
        }

        /// Name
        if(t.type==TT.IDENTIFIER && !t.get.templateType) {
            if(flags.nameForbidden) {
                module_.addError(t, "Variable name not allowed here", true);
            }

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
        } else {
            if(flags.nameRequired) {
                module_.addError(t, "Variable name required", true);
            }
        }

        if(v.type.isUnknown && t.type==TT.LANGLE) {
            t.prev;
            module_.addError(v, "Type %s not found".format(t.value), false);
        }
    }
}