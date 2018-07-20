module ppl2.parse.parse_type;

import ppl2.internal;

final class TypeParser {
private:
    Module module_;
    ModuleParser moduleParser() { return module_.parser; }
    ExpressionParser exprParser() { return module_.exprParser; }
    StatementParser stmtParser() { return module_.stmtParser; }
    VariableParser varParser() { return module_.varParser; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    Type parse(TokenNavigator t, ASTNode node) {
        //dd("parseType");
        string value = t.value;
        Type type    = null;

        if(t.type==TT.LSQBRACKET && t.peek(1).type==TT.COLON) {
            /// array "[:" type count_expr "]"
            type = parseArrayType(t, node);
        } else if(t.type==TT.LSQBRACKET) {
            /// [ <T> ] "[" struct
            type = parseAnonStruct(t, node);
        } else if(t.type==TT.LCURLY) {
            /// {int a,bool->int}
            type = parseFunctionType(t, node);
        } else {
            /// built-in type
            int p = g_builtinTypes.get(value, -1);
            if(p!=-1) {
                t.next;
                type = new BasicType(p);
            }
            /// Is it a NamedStruct or Define?
            if(type is null) {
                type = parseDefine(t, node);
            }
            if(type is null) {
                type = t.get.templateType;
                if(type) t.next;
            }
        }

        /// ptr depth
        if(type !is null) {
            int pd = 0;
            while(t.type==TT.ASTERISK) {
                t.next;
                pd++;
            }
            type = PtrType.of(type, pd);
        }
        return type;
    }
    Type parseDefine(TokenNavigator t, ASTNode node) {
        auto type = findType(t.value, node);
        if(!type) return null;

        t.next;

        Type[] templateParams;

        /// Check for template params
        if(t.type==TT.LANGLE) {
            t.next;

            while(t.type!=TT.RANGLE) {

                t.markPosition();

                auto tt = parse(t, node);
                if(!tt) {
                    t.resetToMark();
                    errorMissingType(t);
                }
                t.discardMark();

                templateParams ~= tt;

                t.expect(TT.COMMA, TT.RANGLE);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);
        }

        if(type.isDefine) {
            auto def = type.getDefine;
            if(def.isKnown) type = def.type;
            defineRequired(def.moduleName, def.name, templateParams);
        } else {
            auto ns = type.getNamedStruct;
            defineRequired(module_.canonicalName, ns.name, templateParams);

            if(ns.isTemplate) {
                if(templateParams.length != ns.templateParamNames.length) {
                    throw new CompilerError(Err.TEMPLATE_INCORRECT_NUM_PARAMS, t,
                        "Expecting %s template parameters".format(ns.templateParamNames.length));
                }

                /// Look for a concrete impl
                Type concreteType;
                string name = ns.name ~ "<" ~ mangle(templateParams) ~ ">";
                if(templateParams.areKnown) {
                    concreteType = findType(name, node);
                }

                if(concreteType) {
                    /// We found the concrete impl
                    type = concreteType;
                } else {
                    /// Create a template proxy Define which can
                    /// be replaced later by the concrete NamedStruct
                    auto def                = makeNode!Define(t);
                    def.name                = module_.makeTemporary("templateProxy");
                    def.type                = TYPE_UNKNOWN;
                    def.moduleName          = module_.canonicalName;
                    def.isImport            = false;
                    def.templateProxyStruct = ns;
                    def.templateProxyParams = templateParams;
                    module_.addToEnd(def);

                    type = def;
                    dd("!!! def=", def.name);
                }
            }
        }
        return type;
    }
    ///
    /// struct_type ::= "[" statement { statement } "]"
    ///
    Type parseAnonStruct(TokenNavigator t, ASTNode node) {

        /// [
        auto s = makeNode!AnonStruct(t);
        node.addToEnd(s);

        t.skip(TT.LSQBRACKET);

        /// Statements
        while(t.type!=TT.RSQBRACKET) {

            stmtParser().parse(t, s);

            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RSQBRACKET);

        return s;
    }
    ///
    /// array_type ::= "[:" type count_expr "]"
    ///
    Type parseArrayType(TokenNavigator t, ASTNode node) {
        auto a = makeNode!ArrayType(t);
        node.addToEnd(a);

        /// [:
        t.skip(TT.LSQBRACKET);
        t.skip(TT.COLON);

        a.subtype = parse(t, a);
        if(a.subtype is null) {
            errorMissingType(t, t.value);
        }

        if(t.type!=TT.RSQBRACKET) {
            /// count
            exprParser().parse(t, a);
        }

        t.skip(TT.RSQBRACKET);

        return a;
    }
    ///
    /// function_type ::= "{" [ type { "," type } ] "->" [ type ] "}"
    ///
    Type parseFunctionType(TokenNavigator t, ASTNode node) {
        //dd("function type");

        t.skip(TT.LCURLY);

        auto f = makeNode!FunctionType(t);
        node.addToEnd(f);

        /// args
        while(t.type!=TT.RT_ARROW) {

            varParser().parse(t, f, true);

            t.expect(TT.RT_ARROW, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }

        /// If type is {void->?} then remove the void to make it 0 params
        if(f.numChildren==1) {
            auto var = f.first().as!Variable;
            if(var.type.isVoid && var.type.isValue) {
                var.detach();
            }
        }

        /// ->
        t.skip(TT.RT_ARROW);

        /// return type
        if(t.type!=TT.RCURLY) {
            varParser().parse(t, f, true);
        } else {
            /// void return type
            auto v = makeNode!Variable(t);
            v.type = TYPE_VOID;
            f.addToEnd(v);
        }

        t.skip(TT.RCURLY);

        return f;
    }
}