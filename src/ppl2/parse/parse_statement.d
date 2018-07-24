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

    bool parse(Tokens t, ASTNode parent) {
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
                return true;
            case "break":
                parseBreak(t, parent);
                return true;
            case "const":
                varParser().parse(t, parent);
                return true;
            case "continue":
                parseContinue(t, parent);
                return true;
            case "define":
                parseDefine(t, parent);
                return true;
            case "extern":
                parseExtern(t, parent);
                return true;
            case "if":
                noExprAllowedAtModuleScope();
                exprParser.parse(t, parent);
                return true;
            case "import":
                return parseImport(t, parent);
            case "loop":
                parseLoop(t, parent);
                return true;
            case "private":
                t.access = Access.PRIVATE;
                t.next;
                return true;
            case "public":
                t.access = Access.PUBLIC;
                t.next;
                return true;
            case "readonly":
                t.access = Access.READONLY;
                t.next;
                return true;
            case "return":
                parseReturn(t, parent);
                return true;
            case "struct":
                namedStructParser().parse(t, parent);
                return true;
            default:
                break;
        }

        if(t.type==TT.SEMICOLON) {
            t.next;
            return true;
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
            return true;
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
            return true;
        }

        /// Handle 'Type type' where Type is not known
        if(parent.isModule && t.type==TT.IDENTIFIER && t.peek(1).type==TT.IDENTIFIER) {
            errorMissingType(t, t.value);
        }

        noExprAllowedAtModuleScope();
        exprParser.parse(t, parent);

        return true;
    }
private: //=============================================================================== private
    /// extern putchar {int->int}
    void parseExtern(Tokens t, ASTNode parent) {
        /// "extern"
        t.next;

        auto f = makeNode!Function(t);
        parent.addToEnd(f);
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
    bool parseImport(Tokens t, ASTNode parent) {

        t.markPosition();

        /// "import"
        t.next;

        /// module name
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

        /// Request exports and pause if they are not already available
        auto mod = PPL2.getModule(moduleName);
        if(!mod) {
            log("Statement: Requesting exports for module %s", moduleName);
            moduleRequired(moduleName);
            t.resetToMark();
            return false;
        } else {
            t.discardMark();
        }

        if(t.isKeyword("as")) {
            assert(false, "import modulename as alias");
        }

        /// For each exported function and type, add proxies to this module
        foreach(f; mod.exportedFunctions.values) {
            auto fn       = makeNode!Function(t);
            fn.name       = f;
            fn.moduleName = moduleName;
            fn.isImport   = true;
            parent.addToEnd(fn);
        }
        foreach(d; mod.exportedTypes.values) {
            auto def        = makeNode!Define(t);
            def.name        = d;
            def.type        = TYPE_UNKNOWN;
            def.moduleName  = moduleName;
            def.isImport    = true;
            parent.addToEnd(def);
        }
        return true;
    }
    ///
    /// define            ::= define_struct | define_non_struct
    /// define_struct     ::= identifier "=" [ template_args ] type
    /// define_non_struct ::= "define" identifier "=" type
    /// template_args     ::= "<" identifier { "," identifier } ">"
    ///
    void parseDefine(Tokens t, ASTNode parent) {

        auto def = makeNode!Define(t);
        parent.addToEnd(def);

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

        /// name
        string name = t.value;
        t.next;

        /// =
        t.skip(TT.EQUALS);

        if(parent.isA!LiteralFunction || (parent.getAncestor!LiteralFunction !is null)) {
            /// This is a closure.
            /// Convert this into a function ptr variable

            assert(t.type!=TT.LANGLE, "closure function template not implemented");

            auto var = makeNode!Variable(t);
            parent.addToEnd(var);

            if(name=="new") newReservedForConstructors(var);

            var.name = name;
            var.type = TYPE_UNKNOWN;

            auto ini = makeNode!Initialiser(t);
            ini.var = var;
            var.addToEnd(ini);

            exprParser().parse(t, ini);
            return;
        }

        auto f = makeNode!Function(t);
        parent.addToEnd(f);

        f.name       = name;
        f.moduleName = module_.canonicalName;

        /// Function template
        if(t.type==TT.LANGLE) {
            /// Template function - just gather the args and tokens
            t.skip(TT.LANGLE);

            /// < .. >
            while(t.type!=TT.RANGLE) {
                f.templateParamNames ~= t.value;
                t.next;
                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            /// {
            t.expect(TT.LCURLY);

            int start = t.index;
            int end   = t.findEndOfBlock(TT.LCURLY);
            f.tokens = t.get(start, start+end).dup;
            t.next(end+1);

            dd("Function template decl", f.name, f.templateParamNames, f.tokens.toString);

        } else {
            /// function literal
            t.expect(TT.LCURLY);
            exprParser().parse(t, f);

            if(f.isTemplateInstance) {
                auto ns = f.getAncestor!NamedStruct;
                if(ns) {
                    /// Add the implicit this* as 1st parameter
                    f.params.addThisParameter(ns);
                }
            }
        }
    }
    ///
    /// return_statement ::= "return" [ expression ]
    ///
    void parseReturn(Tokens t, ASTNode parent) {

        auto r = makeNode!Return(t);
        parent.addToEnd(r);

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
            parent.addToEnd(a);
        }

        parse(t, a);
    }
    void parseBreak(Tokens t, ASTNode parent) {

        auto b = makeNode!Break(t);
        parent.addToEnd(b);

        t.skip("break");
    }
    void parseContinue(Tokens t, ASTNode parent) {
        auto c = makeNode!Continue(t);
        parent.addToEnd(c);

        t.skip("continue");
    }
    void parseLoop(Tokens t, ASTNode parent) {

        auto loop = makeNode!Loop(t);
        parent.addToEnd(loop);

        t.skip("loop");

        t.skip(TT.LBRACKET);

        /// Init statements (must be Variables or Binary)
        auto inits = Composite.make(t, Composite.Usage.PERMANENT);
        loop.addToEnd(inits);

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
        loop.addToEnd(cond);
        if(t.type!=TT.SEMICOLON) {
            exprParser().parse(t, cond);
        } else {

        }

        t.skip(TT.SEMICOLON);

        /// Post loop expressions
        auto post = Composite.make(t, Composite.Usage.PERMANENT);
        loop.addToEnd(post);
        while(t.type!=TT.RBRACKET) {

            exprParser().parse(t, post);

            t.expect(TT.COMMA, TT.RBRACKET);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RBRACKET);

        t.skip(TT.LCURLY);

        /// Body statements
        auto body_ = Composite.make(t, Composite.Usage.PERMANENT);
        loop.addToEnd(body_);

        while(t.type!=TT.RCURLY) {
            parse(t, body_);
        }
        t.skip(TT.RCURLY);
    }
}

