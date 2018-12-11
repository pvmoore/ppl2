module ppl2.parse.parse_statement;

import ppl2.internal;

private const string VERBOSE_MODULE = null; //"test";

final class StatementParser {
private:
    Module module_;

    auto structParser() { return module_.structParser; }
    auto varParser()    { return module_.varParser; }
    auto typeParser()   { return module_.typeParser; }
    auto typeDetector() { return module_.typeDetector; }
    auto exprParser()   { return module_.exprParser; }
    auto attrParser()   { return module_.attrParser; }

    auto builder()      { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }

    void parse(Tokens t, ASTNode parent) {
        static if(VERBOSE_MODULE) {
            if(module_.canonicalName==VERBOSE_MODULE) {
                dd("[", module_.canonicalName, "] statement line:", t.line+1, " parent:", parent.id, "token:", t.get);
                //scope(exit) dd("end statement line:", t.line+1);
            }
        }

        /// Consume and add any attributes
        while(t.type==TT.AT) {
            attrParser().parse(t, parent);
        }

        if(t.type==TT.IDENTIFIER)  {
            switch(t.value) {
                case "alias":
                    parseAlias(t, parent);
                    return;
                case"assert":
                    parseAssert(t, parent);
                    return;
                case "break":
                    parseBreak(t, parent);
                    return;
                case "const":
                    varParser().parseLocal(t, parent);
                    return;
                case "continue":
                    parseContinue(t, parent);
                    return;
                case "enum":
                    parseEnum(t, parent);
                    return;
                case "extern":
                    parseExtern(t, parent);
                    return;
                case "if":
                    noExprAllowedAtModuleScope(t, parent);
                    exprParser.parse(t, parent);
                    return;
                case "import":
                    parseImport(t, parent);
                    return;
                case"loop":
                    parseLoop(t, parent);
                    return;
                case "private":
                    t.setAccess(Access.PRIVATE);
                    checkAccessScope(t, parent);
                    t.next;
                    return;
                case "public":
                    t.setAccess(Access.PUBLIC);
                    checkAccessScope(t, parent);
                    t.next;
                    return;
                case "readonly":
                    t.setAccess(Access.READONLY);
                    checkAccessScope(t, parent);
                    t.next;
                    return;
                case "return":
                    parseReturn(t, parent);
                    return;
                case "select":
                    noExprAllowedAtModuleScope(t, parent);
                    exprParser.parse(t, parent);
                    return;
                case "static":
                    /// static type name
                    /// static type name =
                    /// static name {
                    /// static name <
                    if (t.peek(2).type==TT.LCURLY) {
                        parseFunction(t, parent);
                    } else if (t.peek(2).type==TT.LANGLE) {
                        parseFunction(t, parent);
                    } else {
                        varParser().parseStructMember(t, parent);
                    }
                    return;
                case "struct":
                    structParser().parse(t, parent);
                    return;
                case "operator":
                    if(isOperatorOverloadFunction(module_, t)) {
                        parseFunction(t, parent);
                        return;
                    }
                    break;
                case "#sizeof":
                case "#initof":
                case "#isptr":
                case "#isvalue":
                    noExprAllowedAtModuleScope(t, parent);
                    exprParser.parse(t, parent);
                    return;
                default:
                    break;
            }

            /// name {
            if(t.peek(1).type==TT.LCURLY) {
                parseFunction(t, parent);
                return;
            }
        }
        switch(t.type) with(TT) {
            case SEMICOLON:
                t.next;
                return;
            case LBRACKET:
                errorBadSyntax(module_, t, "Parenthesis not allowed here");
                break;
            default:
                break;
        }

        /// type
        /// type .
        /// type (
        /// type is
        auto node = parent;
        if(node.hasChildren) node = node.last();
        int eot = typeDetector().endOffset(t, node);
        if(eot!=-1) {
            /// First token is a type so this could be one of:
            /// constructor, variable declaration or is_expr
            auto nextTok = t.peek(eot+1);

            if(nextTok.type==TT.DOT) {
                /// dot
                noExprAllowedAtModuleScope(t, parent);
                exprParser.parse(t, parent);
            } else if(nextTok.type==TT.LBRACKET) {
                /// Constructor
                noExprAllowedAtModuleScope(t, parent);
                exprParser.parse(t, parent);
            } else if(nextTok.value=="is") {
                /// is
                noExprAllowedAtModuleScope(t, parent);
                exprParser.parse(t, parent);
            } else {
                /// Variable decl
                varParser().parseLocal(t, parent);
            }

            return;
        }

        /// name < ... > {
        /// name < ... > (
        if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.LANGLE) {

            int end;
            if(isTemplateParams(t, 1, end)) {
                auto nextTok = t.peek(end+1);

                /// name <T> {
                if(nextTok.type==TT.LCURLY) {
                    parseFunction(t, parent);
                    return;
                }

                /// identifier<params> not followed by a '(' or '{'
                /// indicates a missing type
                if(nextTok.type!=TT.LBRACKET) {
                    errorMissingType(module_, t);
                }
            }
        }

        /// Test for 'Type type' where Type is not known
        if(parent.isModule && t.type==TT.IDENTIFIER && t.peek(1).type==TT.IDENTIFIER) {
            errorMissingType(module_, t, t.value);
        }

        /// It must be an expression
        noExprAllowedAtModuleScope(t, parent);
        exprParser.parse(t, parent);
    }
private: //=============================================================================== private
    void noExprAllowedAtModuleScope(Tokens t, ASTNode parent) {
        if(parent.isA!Module) {
            errorBadSyntax(module_, t, "Expressions not allowed at module scope. Did you mean define?");
        }
    }
    void checkAccessScope(Tokens t, ASTNode parent) {
        if(parent.id==NodeID.STRUCT) {
            return;
        }
        if(parent.id==NodeID.MODULE) {
            if(t.value=="readonly") {
                module_.addError(t, "readonly access is only allowed inside a struct", true);
            }
            return;
        }
        module_.addError(t, "Access qualifiers only allowed at module or struct scope", true);
    }

    /// extern putchar {int->int}
    void parseExtern(Tokens t, ASTNode parent) {
        /// "extern"
        t.next;

        auto f = makeNode!Function(t);
        parent.add(f);
        f.moduleName = module_.canonicalName;
        f.isExtern   = true;

        /// name
        f.name = t.value;
        t.next;

        /// type
        f.externType = typeParser().parse(t, f);
    }
    ///
    /// import       ::= "import" [identifier "="] module_paths
    /// module_path  ::= identifier { "::" identifier }
    /// module_paths ::= module_path { "," module-path }
    ///
    void parseImport(Tokens t, ASTNode parent) {

        /// "import"
        t.next;

        while(true) {
            auto imp = makeNode!Import(t);
            parent.add(imp);

            string collectModuleName() {
                string moduleName = t.value;
                t.markPosition();
                t.next;

                while(t.type==TT.DBL_COLON) {
                    t.next;
                    moduleName ~= "::";
                    moduleName ~= t.value;
                    t.next;
                }

                /// Check that the import exists
                import std.file : exists;
                if(!exists(module_.config.getFullModulePath(moduleName))) {
                    t.resetToMark();
                    module_.addError(t, "Module %s does not exist".format(moduleName), false);
                }
                t.discardMark();
                return moduleName;
            }

            if(t.peek(1).type==TT.EQUALS) {
                /// module_alias = canonicalName
                imp.aliasName = t.value;
                t.next(2);

                if(findImportByAlias(imp.aliasName, imp.previous())) {
                    module_.addError(imp, "Module alias %s already found in this scope".format(imp.aliasName), true);
                }
            }

            imp.moduleName = collectModuleName();

            if(findImportByCanonicalName(imp.moduleName, imp)) {
                module_.addError(imp, "Module %s already imported".format(imp.moduleName), true);
            }

            /// Trigger the loading of the module
            imp.mod = module_.buildState.getOrCreateModule(imp.moduleName);

            /// For each exported function and type, add proxies to this module
            foreach (f; imp.mod.parser.publicFunctions.values) {
                auto fn       = makeNode!Function(t);
                fn.name       = f;
                fn.moduleName = imp.moduleName;
                fn.isImport   = true;
                imp.add(fn);
            }
            foreach (d; imp.mod.parser.publicTypes.values) {
                auto def        = makeNode!Alias(t);
                def.name        = d;
                def.type        = TYPE_UNKNOWN;
                def.moduleName  = imp.moduleName;
                def.isImport    = true;
                imp.add(def);
            }

            if(t.type==TT.COMMA) {
                t.next;
            } else break;
        }
    }
    ///
    /// alias ::= "alias" identifier "=" type
    ///
    void parseAlias(Tokens t, ASTNode parent) {

        auto alias_ = makeNode!Alias(t);
        parent.add(alias_);

        alias_.access = t.access();

        /// "alias"
        t.skip("alias");

        /// identifier
        alias_.name = t.value;
        t.next;

        /// =
        t.skip(TT.EQUALS);

        /// type
        alias_.type = typeParser().parse(t, alias_);
        //dd("alias_", alias_.name, "type=", alias_.type, "root=", alias_.getRootType);

        alias_.isImport   = false;
        alias_.moduleName = module_.canonicalName;
    }
    ///
    /// function::= [ "static" ] identifier [ template params] expr_function_literal
    ///
    void parseFunction(Tokens t, ASTNode parent) {

        auto f = makeNode!Function(t);
        parent.add(f);

        auto ns = f.getAncestor!Struct;

        if(t.value=="static") {
            f.isStatic = true;
            t.next;
        }

        /// name
        f.name           = t.value;
        f.moduleName     = module_.canonicalName;
        f.isProgramEntry = module_.isMainModule && f.name=="main";
        t.next;

        if(f.isStatic && f.name=="new") {
            module_.addError(t, "Struct constructors cannot be static", true);
        }

        if(f.name=="operator" && ns) {
            /// Operator overload

            f.op = parseOperator(t);
            f.name ~= f.op.value;
            t.next;

            if(f.op==Operator.NOTHING) errorBadSyntax(module_, t, "Expecting an overloadable operator");
        }

        /// Function readonly access is effectively public
        f.access = t.access()==Access.PRIVATE ? Access.PRIVATE : Access.PUBLIC;

        /// =
        if(t.type==TT.EQUALS) {
            t.skip(TT.EQUALS);
            assert(false, "shouldn't get here");
        }

        /// Function template
        if(t.type==TT.LANGLE) {
            /// Template function - just gather the args and tokens
            t.skip(TT.LANGLE);

            f.blueprint = new TemplateBlueprint(module_);
            string[] paramNames;

            /// < .. >
            while(t.type!=TT.RANGLE) {

                if(typeDetector().isType(t, f)) {
                    module_.addError(t, "Template param name cannot be a type", true);
                }

                paramNames ~= t.value;
                t.next;
                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            /// {
            t.expect(TT.LCURLY);

            int start = t.index;
            int end   = t.findEndOfBlock(TT.LCURLY);
            f.blueprint.setFunctionTokens(ns, paramNames, t[start..start+end+1].dup);
            t.next(end+1);

            //dd("Function template decl", f.name, f.blueprint.paramNames, f.blueprint.tokens.toString);

        } else {

            /// function literal
            t.expect(TT.LCURLY);
            exprParser().parse(t, f);

            /// Add implicit this* parameter if this is a non-static struct member function
            if(ns && !f.isStatic) {
                f.params.addThisParameter(ns);
            }
        }
    }
    ///
    /// return_statement ::= "return" [ expression ]
    ///
    void parseReturn(Tokens t, ASTNode parent) {

        auto r = makeNode!Return(t);
        parent.add(r);

        int line = t.get().line;

        /// return
        t.next;

        /// [ expression ]
        /// This is a bit of a hack.
        /// If there is something on the same line and it's not a '}'
        /// then assume there is a return expression
        if(t.type!=TT.RCURLY && t.get().line==line) {
            exprParser().parse(t, r);
        }
    }
    void parseAssert(Tokens t, ASTNode parent) {
        t.skip("assert");

        auto a = makeNode!Assert(t);

        /// Only add if asserts are enabled
        if(module_.config.enableAsserts) {
            parent.add(a);
        }

        exprParser().parse(t, a);
    }
    void parseBreak(Tokens t, ASTNode parent) {

        auto b = makeNode!Break(t);
        parent.add(b);

        t.skip("break");
    }
    void parseContinue(Tokens t, ASTNode parent) {
        auto c = makeNode!Continue(t);
        parent.add(c);

        t.skip("continue");
    }
    void parseLoop(Tokens t, ASTNode parent) {

        auto loop = makeNode!Loop(t);
        parent.add(loop);

        t.skip("loop");

        t.skip(TT.LBRACKET);

        /// Init statements (must be Variables or Binary)
        auto inits = Composite.make(t, Composite.Usage.PERMANENT);
        loop.add(inits);

        if(t.type==TT.RBRACKET) errorBadSyntax(module_, t, "Expecting loop initialiser");

        while(t.type!=TT.SEMICOLON) {

            parse(t, inits);

            t.expect(TT.COMMA, TT.SEMICOLON);
            if(t.type==TT.COMMA) t.next;
        }

        t.skip(TT.SEMICOLON);

        if(t.type==TT.RBRACKET) errorBadSyntax(module_, t, "Expecting loop condition");

        /// Condition
        auto cond = Composite.make(t, Composite.Usage.PERMANENT);
        loop.add(cond);
        if(t.type!=TT.SEMICOLON) {
            exprParser().parse(t, cond);
        } else {

        }

        t.skip(TT.SEMICOLON);

        /// Post loop expressions
        auto post = Composite.make(t, Composite.Usage.PERMANENT);
        loop.add(post);
        while(t.type!=TT.RBRACKET) {

            exprParser().parse(t, post);

            t.expect(TT.COMMA, TT.RBRACKET);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RBRACKET);

        t.skip(TT.LCURLY);

        /// Body statements
        auto body_ = Composite.make(t, Composite.Usage.PERMANENT);
        loop.add(body_);

        while(t.type!=TT.RCURLY) {
            parse(t, body_);
        }
        t.skip(TT.RCURLY);
    }
    void parseEnum(Tokens t, ASTNode parent) {

        auto e = makeNode!Enum(t);
        parent.add(e);

        e.access = t.access();

        /// enum
        t.skip("enum");

        /// name
        e.name       = t.value;
        e.moduleName = module_.canonicalName;
        t.next;

        /// : type (optional)
        if(t.type==TT.COLON) {
            t.next;

            e.elementType = typeParser.parse(t, e);
        }

        /// {
        t.skip(TT.LCURLY);

        while(t.type!=TT.RCURLY) {

            auto value = makeNode!EnumMember(t);
            e.add(value);

            /// name
            value.name = t.value;
            value.type = e;
            t.next;

            if(t.type==TT.EQUALS) {
                t.next;

                exprParser().parse(t, value);
            }

            t.expect(TT.COMMA, TT.RCURLY);
            if(t.type==TT.COMMA) t.next;
        }

        /// }
        t.skip(TT.RCURLY);
    }
}

