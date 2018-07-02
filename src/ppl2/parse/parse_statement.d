module ppl2.parse.parse_statement;

import ppl2.internal;

final class StatementParser {
private:
    Module module_;

    NamedStructParser namedStructParser() { return module_.namedStructParser; }
    VariableParser varParser() { return module_.varParser; }
    TypeParser typeParser() { return module_.typeParser; }
    ExpressionParser exprParser() { return module_.exprParser; }
    NodeBuilder builder() { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }

    bool parse(TokenNavigator t, ASTNode parent) {
        //dd(module_.canonicalName, "statement line=", t.line," parent", parent);
        //scope(exit) dd("end statement line", t.line);

        pragma(inline,true) {
            void noExprAllowedAtModuleScope() {
                if(parent.isA!Module) {
                    errorBadSyntax(t, "Expressions not allowed at module scope. Did you mean define?");
                }
            }
            bool isAType(int offset) {
                t.markPosition();
                t.next(offset);

                bool result = typeParser().isType(t, parent);

                t.resetToMark();
                return result;
            }
        }

        if(t.isKeyword("public")) {
            t.access = Access.PUBLIC;
            t.next;
            return true;
        }
        if(t.isKeyword("private")) {
            t.access = Access.PRIVATE;
            t.next;
            return true;
        }
        if(t.isKeyword("readonly")) {
            t.access = Access.READONLY;
            t.next;
            return true;
        }
        if(t.isKeyword("export")) {
            parseExport(t, parent);
            return true;
        }
        if(t.isKeyword("extern")) {
            parseExtern(t, parent);
            return true;
        }
        if(t.isKeyword("import")) {
            return parseImport(t, parent);
        }
        if(t.isKeyword("if")) {
            assert(false, "if");
        }
        if(t.isKeyword("return")) {
            parseReturn(t, parent);
            return true;
        }
        if(t.isKeyword("const")) {
            varParser().parse(t, parent);
            return true;
        }
        if(t.isKeyword("define")) {
            parseDefine(t, parent);
            return true;
        }
        if(t.isKeyword("assert")) {
            parseAssert(t, parent);
            return true;
        }

        if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.EQUALS) {

            if(t.peek(2).type==TT.LCURLY) {
                /// name = {
                parseFunction(t, parent);
            } else if(t.peek(2).type==TT.LSQBRACKET && isAType(2)) {
                /// name = [
                namedStructParser().parse(t, parent);
            } else {
                /// name = expr
                noExprAllowedAtModuleScope();
                exprParser.parse(t, parent);
            }
            return true;
        }

        if(typeParser().isType(t, parent)) {
            varParser().parse(t, parent);
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
    void parseExtern(TokenNavigator t, ASTNode parent) {
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
    /// export_stmt ::= "export" { identifier [ "," identifier ] }
    ///
    void parseExport(TokenNavigator t, ASTNode parent) {
        /// export
        t.next;

        /// 1st export
        t.next;

        while(t.type==TT.COMMA) {
            t.skip(TT.COMMA);
            /// export
            t.next;
        }
    }
    ///
    /// import::= "import" module_name [ "as" identifier ]
    ///
    bool parseImport(TokenNavigator t, ASTNode parent) {

        t.markPosition();

        /// "import"
        t.next;

        /// module name
        string moduleName = t.value;
        t.next;

        while(t.type==TT.DOT) {
            t.next;
            moduleName ~= ".";
            moduleName ~= t.value;
            t.next;
        }

        /// Request exports and pause if they are not already available
        auto mod = PPL2.getModule(moduleName);
        if(!mod) {
            log("Statement: Requesting exports for module %s", moduleName);
            exportsRequired(moduleName);
            t.resetToMark();
            return false;
        } else {
            t.discardMark();
        }

        if(t.isKeyword("as")) {
            assert(false, "import modulename as alias");
        }

        /// For each exported function and type, add proxies to this module
        foreach(f; mod.exportedFunctions) {
            auto fn       = makeNode!Function(t);
            fn.name       = f;
            fn.moduleName = moduleName;
            fn.isImport   = true;
            parent.addToEnd(fn);
        }
        foreach(d; mod.exportedTypes) {
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
    void parseDefine(TokenNavigator t, ASTNode parent) {

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
    /// function::= identifier "=" expr_function_literal
    ///
    void parseFunction(TokenNavigator t, ASTNode parent) {

        auto f = makeNode!Function(t);
        parent.addToEnd(f);

        f.moduleName = module_.canonicalName;

        /// name
        f.name = t.value;
        t.next;

        if(f.name=="new" && f.isClosure) newReservedForConstructors(f);

        /// =
        t.skip(TT.EQUALS);

        /// function literal
        exprParser().parse(t, f);
    }
    ///
    /// return_statement ::= "return" [ expression ]
    ///
    void parseReturn(TokenNavigator t, ASTNode parent) {

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
    void parseAssert(TokenNavigator t, ASTNode parent) {
        auto a = makeNode!Assert(t);
        parent.addToEnd(a);

        t.skip("assert");

        exprParser().parse(t, a);
    }
}

