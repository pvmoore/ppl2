module ppl2.parse.parse_statement;

import ppl2.internal;

final class StatementParser {
private:
    Module module_;

    NamedStructParser namedStructParser() { return module_.namedStructParser; }
    VariableParser varParser() { return module_.varParser; }
    TypeParser typeParser() { return module_.typeParser; }
    TypeDetector typeDetector() { return module_.typeDetector; }
    ExpressionParser exprParser() { return module_.exprParser; }
    NodeBuilder builder() { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }

    void parse(Tokens t, ASTNode parent) {
        //dd(module_.canonicalName, "statement line=", t.line, " parent", parent, t.get);
        //scope(exit) dd("end statement line", t.line);

        pragma(inline,true) {
            void noExprAllowedAtModuleScope() {
                if(parent.isA!Module) {
                    errorBadSyntax(t, "Expressions not allowed at module scope. Did you mean define?");
                }
            }
        }

        switch(t.value) {
            case "assert":
                parseAssert(t, parent);
                return;
            case "break":
                parseBreak(t, parent);
                return;
            case "const":
                varParser().parse(t, parent);
                return;
            case "continue":
                parseContinue(t, parent);
                return;
            case "define":
                parseDefine(t, parent);
                return;
            case "extern":
                parseExtern(t, parent);
                return;
            case "if":
                noExprAllowedAtModuleScope();
                exprParser.parse(t, parent);
                return;
            case "import":
                parseImport(t, parent);
                return;
            case "loop":
                parseLoop(t, parent);
                return;
            case "private":
                t.setAccess(Access.PRIVATE);
                t.next;
                return;
            case "public":
                t.setAccess(Access.PUBLIC);
                t.next;
                return;
            case "readonly":
                t.setAccess(Access.READONLY);
                t.next;
                return;
            case "return":
                parseReturn(t, parent);
                return;
            case "struct":
                namedStructParser().parse(t, parent);
                return;
            case "operator":
                if(isOperatorOverloadFunction(t)) {
                    parseFunction(t, parent);
                    return;
                }
                break;
            default:
                break;
        }

        if(t.type==TT.SEMICOLON) {
            t.next;
            return;
        }

        if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.EQUALS) {
            /// Could be a function, a named struct or a binary expression

            if(t.peek(2).type==TT.LCURLY || t.peek(2).type==TT.LANGLE) {
                /// name = {
                /// name = <
                parseFunction(t, parent);
            } else {
                /// name = expr
                noExprAllowedAtModuleScope();
                exprParser.parse(t, parent);
            }
            return;
        }

        int eot = typeDetector().endOffset(t, parent);
        if(eot!=-1) {
            /// First token is a type so this could be one of:
            /// constructor, variable declaration or is_expr
            auto nextTok = t.peek(eot+1);

            if(nextTok.type==TT.LBRACKET) {
                /// Constructor
                noExprAllowedAtModuleScope();
                exprParser.parse(t, parent);
            } else if(nextTok.value=="is") {
                noExprAllowedAtModuleScope();
                exprParser.parse(t, parent);
            } else if(nextTok.type==TT.DOT) {
                noExprAllowedAtModuleScope();
                exprParser.parse(t, parent);
            } else {
                /// Variable decl
                varParser().parse(t, parent);
            }
            return;
        }

        /// Test for identifier<...> not followed by a '('
        /// which indicates a missing type
        if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.LANGLE) {
            auto end = t.findEndOfBlock(TT.LANGLE, 1);
            if(end!=-1 && t.peek(end+1).type!=TT.LBRACKET) {
                errorMissingType(t);
            }
        }

        /// Test for 'Type type' where Type is not known
        if(parent.isModule && t.type==TT.IDENTIFIER && t.peek(1).type==TT.IDENTIFIER) {
            errorMissingType(t, t.value);
        }

        noExprAllowedAtModuleScope();
        exprParser.parse(t, parent);
    }
private: //=============================================================================== private
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
    /// import::= "import" module_name [ "as" identifier ]
    ///
    void parseImport(Tokens t, ASTNode parent) {

        auto imp = makeNode!Import(t);
        parent.add(imp);

        /// "import"
        t.next;

        string collectModuleName() {
            string moduleName = t.value;
            t.markPosition();
            t.next;

            while(t.type==TT.DOT) {
                t.next;
                moduleName ~= ".";
                moduleName ~= t.value;
                t.next;
            }

            /// Check that the import exists
            import std.file : exists;
            if(!exists(Module.getFullPath(moduleName))) {
                t.resetToMark();
                throw new CompilerError(Err.MODULE_DOES_NOT_EXIST, t,
                    "Module %s does not exist".format(moduleName));
            }
            t.discardMark();
            return moduleName;
        }

        imp.moduleName = collectModuleName();

        if(findImport(imp.moduleName, imp)) {
            throw new CompilerError(Err.IMPORT_DUPLICATE, imp, "Module %s already imported".format(imp.moduleName));
        }

        /// Trigger the loading of the module
        imp.mod = PPL2.getModule(imp.moduleName);

        if(t.isKeyword("as")) {
            assert(false, "import modulename as alias");
        }

        /// For each exported function and type, add proxies to this module
        foreach(f; imp.mod.exportedFunctions.values) {
            auto fn       = makeNode!Function(t);
            fn.name       = f;
            fn.moduleName = imp.moduleName;
            fn.moduleNID  = imp.mod.nid;
            fn.isImport   = true;
            imp.add(fn);
        }
        foreach(d; imp.mod.exportedTypes.values) {
            auto def        = makeNode!Define(t);
            def.name        = d;
            def.type        = TYPE_UNKNOWN;
            def.moduleName  = imp.moduleName;
            def.moduleNID   = imp.mod.nid;
            def.isImport    = true;
            imp.add(def);
        }
    }
    ///
    /// define            ::= define_struct | define_non_struct
    /// define_struct     ::= identifier "=" [ template_args ] type
    /// define_non_struct ::= "define" identifier "=" type
    /// template_args     ::= "<" identifier { "," identifier } ">"
    ///
    void parseDefine(Tokens t, ASTNode parent) {

        auto def = makeNode!Define(t);
        parent.add(def);

        /// "define"
        t.skip("define");

        /// identifier
        def.name = t.value;
        t.next;

        /// =
        t.skip(TT.EQUALS);

        /// type
        def.type = typeParser().parse(t, def);
        //dd("def", def.name, "type=", def.type, "root=", def.getRootType);

        def.isImport   = false;
        def.moduleName = module_.canonicalName;
    }
    ///
    /// function::= identifier "=" [ template params] expr_function_literal
    ///
    void parseFunction(Tokens t, ASTNode parent) {

        auto f = makeNode!Function(t);
        parent.add(f);

        auto ns = f.getAncestor!NamedStruct;

        /// name
        f.name       = t.value;
        f.moduleName = module_.canonicalName;
        f.moduleNID  = module_.nid;
        t.next;

        if(f.name=="operator" && ns) {
            /// Operator overload

            f.op = parseOperator(t);
            f.name ~= f.op.value;
            t.next;

            if(f.op==Operator.NOTHING) errorBadSyntax(t, "Expecting an overloadable operator");
        }

        /// Function readonly access is effectively public
        f.access = t.access()==Access.PRIVATE ? Access.PRIVATE : Access.PUBLIC;

        /// =
        t.skip(TT.EQUALS);

        /// Function template
        if(t.type==TT.LANGLE) {
            /// Template function - just gather the args and tokens
            t.skip(TT.LANGLE);

            f.blueprint = new TemplateBlueprint;

            /// < .. >
            while(t.type!=TT.RANGLE) {

                if(typeDetector().isType(t, f)) {
                    throw new CompilerError(Err.TEMPLATE_PARAM_NAME_IS_TYPE, t,
                        "Template param name cannot be a type");
                }

                f.blueprint.paramNames ~= t.value;
                t.next;
                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            /// {
            t.expect(TT.LCURLY);

            int start = t.index;
            int end   = t.findEndOfBlock(TT.LCURLY);
            f.blueprint.setTokens(ns, t.get(start, start+end).dup);
            t.next(end+1);

            //dd("Function template decl", f.name, f.blueprint.paramNames, f.blueprint.tokens.toString);

        } else {

            /// function literal
            t.expect(TT.LCURLY);
            exprParser().parse(t, f);

            /// Add implicit this* as 1st parameter if this is a struct member function
            if(ns) {
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
        if(getConfig().enableAsserts) {
            parent.add(a);
        }

        parse(t, a);
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

        if(t.type==TT.RBRACKET) errorBadSyntax(t, "Expecting loop initialiser");

        while(t.type!=TT.SEMICOLON) {

            parse(t, inits);

            t.expect(TT.COMMA, TT.SEMICOLON);
            if(t.type==TT.COMMA) t.next;
        }

        t.skip(TT.SEMICOLON);

        if(t.type==TT.RBRACKET) errorBadSyntax(t, "Expecting loop condition");

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
}

