module ppl2.parse.parse_expression;

import ppl2.internal;

private const string VERBOSE_MODULE = null; //"test";

final class ExpressionParser {
private:
    Module module_;

    auto typeParser()   { return module_.typeParser; }
    auto typeDetector() { return module_.typeDetector; }
    auto stmtParser()   { return module_.stmtParser; }
    auto varParser()    { return module_.varParser; }
    auto attrParser()   { return module_.attrParser; }
    auto typeFinder()   { return module_.typeFinder; }
    auto builder()      { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }

    void parse(Tokens t, ASTNode parent) {
        //dd("expression", t.get);

        parseLHS(t, parent);
        parseRHS(t, parent);
    }
private:
    void parseLHS(Tokens t, ASTNode parent) {
        static if(VERBOSE_MODULE) {
            if(module_.canonicalName==VERBOSE_MODULE) dd("lhs", t.get, "parent=", parent.id);
        }

        /// Consume and add any attributes
        while(t.type==TT.AT) {
            attrParser().parse(t, parent);
        }

        /// Simple identifiers
        if(t.type==TT.IDENTIFIER) {
            switch(t.value) {
                case "if":
                    parseIf(t, parent);
                    return;
                case "select":
                    parseSelect(t, parent);
                    return;
                case "not":
                    parseUnary(t, parent);
                    return;
                case "operator":
                    parseCall(t, parent);
                    return;
                case "#typeof":
                case "#sizeof":
                case "#initof":
                case "#isptr":
                case "#isvalue":
                case "#alignof":
                    parseBuiltinFunc(t, parent);
                    return;
                default:
                    break;
            }
        }

        /// Handle Enum members. Do this before type detection because the member
        /// value may look like a type eg. Enum::Thing (where Thing is also a type declared elsewhere)
        if(parent.isDot && t.type==TT.IDENTIFIER) {
            assert(parent.hasChildren);

            auto type = parent.first().getType;
            if(type.isEnum && parent.first.id==NodeID.TYPE_EXPR) {
                parseIdentifier(t, parent);
                return;
            }
        }

        /// type
        /// type (
        int eot = typeDetector().endOffset(t, parent);
        if(eot!=-1) {
            auto nextTok = t.peek(eot+1);

            if(nextTok.type==TT.LBRACKET) {
                /// type(
                parseConstructor(t, parent);
                return;
            }

            parseTypeExpr(t, parent);
            return;
        }

        /// Simple literals
        if(t.type==TT.NUMBER || t.type==TT.CHAR || "true"==t.value || "false"==t.value || "null"==t.value) {
            parseLiteral(t, parent);
            return;
        }

        /// More complex identifiers
        /// name (
        /// name.name {
        /// name <
        /// name::
        /// name
        if(t.type==TT.IDENTIFIER) {

            if(t.peek(1).type==TT.LBRACKET) {
                parseCall(t, parent);
                return;
            }
            if(t.peek(1).type==TT.LCURLY) {
                /// Groovy-style call with funcptr arg
                /// func { a-> }
                if(parent.isDot) {
                    parseCall(t, parent);
                    return;
                }
            }
            if(t.peek(1).type==TT.LANGLE) {
                /// Could be a call or a Binary name < expr
                int end;
                if(isTemplateParams(t, 1, end)) {
                    parseCall(t, parent);
                    return;
                }
            }
            if(t.peek(1).type==TT.DOT) {
                auto node = parent.hasChildren ? parent.last : parent;
                auto imp  = findImportByAlias(t.value, node);
                if(imp) {
                    parseModuleAlias(t, parent, imp);
                    return;
                }
            }
            if(t.peek(1).type==TT.DBL_COLON) {
                auto node = parent.hasChildren ? parent.last : parent;
                auto imp  = findImportByAlias(t.value, node);
                if(imp) {
                    parseModuleAlias(t, parent, imp);
                    return;
                }
            }

            parseIdentifier(t, parent);
            return;
        }

        /// Everything else
        switch(t.type) with(TT) {
            case STRING:
                parseLiteralString(t, parent);
                break;
            case LBRACKET:
                parseParenthesis(t, parent);
                break;
            case LSQBRACKET:
                if(isObviouslyATupleLiteral(t)) {
                    parseLiteralTuple(t, parent);
                } else {
                    /// Could be a LiteralTuple or a LiteralArray
                    parseLiteralExprList(t, parent);
                }
                break;
            case LCURLY:
                parseLiteralFunction(t, parent);
                break;
            case MINUS:
            case TILDE:
                parseUnary(t, parent);
                break;
            case AMPERSAND:
                parseAddressOf(t, parent);
                break;
            case ASTERISK:
                parseValueOf(t, parent);
                break;
            case EXCLAMATION:
                errorBadSyntax(module_, t, "Did you mean 'not'");
                break;
            default:
                //errorBadSyntax(t, "Syntax error");
                //writefln("BAD LHS %s", t.get);
                //parent.getModule.dumpToConsole();
                //module_.addError(t, "Bad LHS", false);
                errorBadSyntax(module_, t, "Syntax error at %s".format(t.type));
                break;
        }
    }
    void parseRHS(Tokens t, ASTNode parent) {

        while(true) {
            //dd("rhs", t.get, "parent=", parent.id);

            if("is"==t.value) {
                parent = attachAndRead(t, parent, parseIs(t));
            } else if("as"==t.value) {
                parent = attachAndRead(t, parent, parseAs(t));
            } else if("and"==t.value || "or"==t.value) {
                parent = attachAndRead(t, parent, parseBinary(t));
            } else switch(t.type) {
                case TT.NONE:
                case TT.LCURLY:
                case TT.RCURLY:
                case TT.LBRACKET:
                case TT.RBRACKET:
                case TT.RSQBRACKET:
                case TT.NUMBER:
                case TT.COMMA:
                case TT.SEMICOLON:
                case TT.COLON:
                case TT.AT:
                    /// end of expression
                    return;
                case TT.PLUS:
                case TT.MINUS:
                case TT.DIV:
                case TT.PERCENT:
                case TT.HAT:
                case TT.SHL:
                case TT.SHR:
                case TT.USHR:
                case TT.LANGLE:
                case TT.RANGLE:
                case TT.LTE:
                case TT.GTE:
                case TT.EQUALS:
                case TT.ADD_ASSIGN:
                case TT.SUB_ASSIGN:
                case TT.MUL_ASSIGN:
                case TT.MOD_ASSIGN:
                case TT.DIV_ASSIGN:
                case TT.BIT_AND_ASSIGN:
                case TT.BIT_XOR_ASSIGN:
                case TT.BIT_OR_ASSIGN:
                case TT.SHL_ASSIGN:
                case TT.SHR_ASSIGN:
                case TT.USHR_ASSIGN:
                case TT.BOOL_EQ:
                case TT.COMPARE:
                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.ASTERISK:
                    /// Must be on the same line as LHS otherwise will look like deref *
                    if(!t.onSameLine) return;

                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.AMPERSAND:
                    if(t.peek(1).type==TT.AMPERSAND) errorBadSyntax(module_, t, "Did you mean 'and'");
                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.PIPE:
                    if(t.peek(1).type==TT.PIPE) errorBadSyntax(module_, t, "Did you mean 'or'");
                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.LSQBRACKET:
                    /// array literal
                    if(t.peek(1).type==TT.COLON) return;

                    /// Tuple or Array
                    if(typeDetector().isType(t, parent, 1)) {
                        return;
                    }
                    parent = attachAndRead(t, parent, parseIndex(t, parent), false);
                    break;
                case TT.DBL_COLON:
                    errorBadSyntax(module_, t, "Not expecting :: Did you mean . ?");
                    break;
                case TT.DOT:
                    parent = attachAndRead(t, parent, parseDot(t));
                    break;
                case TT.IDENTIFIER:
                    if(t.value=="and" || t.value=="or") {
                        parent = attachAndRead(t, parent, parseBinary(t));
                        break;
                    }
                    /// end of expression
                    return;
                default:
                    writefln("BAD RHS %s", t.get);
                    parent.getModule.dumpToConsole();
                    module_.addError(t, "Bad RHS", false);
            }
        }
    }
    Expression attachAndRead(Tokens t, ASTNode parent, Expression newExpr, bool andRead = true) {
        //dd("attach", newExpr.id, "to", parent.id);

        ASTNode prev = parent;

        ///
        /// Swap expressions according to operator precedence
        ///
        const doPrecedenceCheck = prev.isA!Expression;
        if(doPrecedenceCheck) {

            /// Adjust to account for operator precedence
            Expression prevExpr = prev.as!Expression;
            while(prevExpr.parent &&
                  newExpr.priority >= prevExpr.priority)
            {

                if(!prevExpr.parent.isExpression) {
                    prev = prevExpr.parent;
                    break;
                }

                prevExpr = prevExpr.parent.as!Expression;
                prev     = prevExpr;
            }
        }

        newExpr.add(prev.last);
        prev.add(newExpr);

        if(andRead) {
            parseLHS(t, newExpr);
        }

        return newExpr;
    }
    ///
    /// binary_expr ::= expression operator expression
    /// operator ::= "=" | "+" | "-" etc...
    ///
    ///
    Expression parseBinary(Tokens t) {

        auto b = makeNode!Binary(t);

        if("and"==t.value) {
            b.op = Operator.BOOL_AND;
        } else if("or"==t.value) {
            b.op = Operator.BOOL_OR;
        } else {
            b.op = parseOperator(t);
            if(b.op==Operator.NOTHING) {
                module_.addError(t, "Invalid operator", true);
            }
        }

        t.next;

        return b;
    }
    ///
    /// dot_expr ::= expression ("." | "::") expression
    ///
    Expression parseDot(Tokens t) {

        auto d = makeNode!Dot(t);

        if(t.type==TT.DOT) {
            t.skip(TT.DOT);
        } else {
            t.skip(TT.DBL_COLON);
        }

        return d;
    }
    Expression parseIndex(Tokens t, ASTNode parent) {

        auto i = makeNode!Index(t);
        parent.add(i);

        t.skip(TT.LSQBRACKET);

        auto parens = makeNode!Parenthesis(t);
        i.add(parens);

        parse(t, parens);

        t.skip(TT.RSQBRACKET);

        i.detach();

        return i;
    }
    ///
    /// expression "as" type
    ///
    Expression parseAs(Tokens t) {

        auto a = makeNode!As(t);

        t.skip("as");

        return a;
    }
    Expression parseIs(Tokens t) {
        auto i = makeNode!Is(t);

        t.skip("is");

        if(t.value=="not") {
            t.skip("not");
            i.negate = true;
        }

        return i;
    }
    void parseTypeExpr(Tokens t, ASTNode parent) {
        auto e = makeNode!TypeExpr(t);
        parent.add(e);

        e.type = typeParser().parse(t, e);

        if(e.type is null) {
            errorMissingType(module_, t, t.value);
        }
    }
    ///
    /// literal_number |
    /// literal_string |
    /// literal_char
    ///
    void parseLiteral(Tokens t, ASTNode parent) {
        Expression e;

        if(t.type==TT.NUMBER || t.type==TT.CHAR || t.value=="true" || t.value=="false") {
            auto lit = makeNode!LiteralNumber(t);
            lit.str = t.value;
            e = lit;
            parent.add(e);
            lit.determineType();
            t.next;
        } else if("null"==t.value) {
            e = makeNode!LiteralNull(t);
            parent.add(e);
            t.next;
        } else {
            assert(false, "How did we get here?");
        }
    }
    ///
    /// call_expression::= identifier [template args] "(" [ expression ] { "," expression } ")"
    ///
    void parseCall(Tokens t, ASTNode parent) {

        auto c = makeNode!Call(t);
        parent.add(c);

        c.target = new Target(module_);
        c.name = t.value;
        t.next;

        if(c.name=="new") {
            ///
            /// This is a construtor call. We don't currently allow this
            ///
            module_.addError(c, "Explicit constructor calls not allowed", true);
        }

        if(c.name=="operator") {
            /// Call to operator overload

            auto op = parseOperator(t);
            if(!op.isOverloadable) errorBadSyntax(module_, t, "Expecting an overloadable operator");

            c.name ~= op.value;
            t.next;

            if(op==Operator.NOTHING) errorBadSyntax(module_, t, "Expecting an overloadable operator");
        }

        /// template args
        if(t.type==TT.LANGLE) {
            t.next;

            while(t.type!=TT.RANGLE) {

                t.markPosition();

                auto tt = typeParser().parse(t, c);
                if(!tt) {
                    t.resetToMark();
                    errorMissingType(module_, t);
                }
                t.discardMark();

                c.templateTypes ~= tt;

                t.expect(TT.COMMA, TT.RANGLE);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            //dd("Function template call", c.name, c.templateTypes);
        }

        if(t.type==TT.LBRACKET) {
            t.skip(TT.LBRACKET);

            import common : contains;

            /// Add args to a Composite to act as a ceiling so that
            /// the operator precedence never moves them above the call
            auto composite = Composite.make(t, Composite.Usage.STANDARD);
            c.add(composite);

            while(t.type!=TT.RBRACKET) {

                if(t.peek(1).type==TT.COLON) {
                    /// paramname = expr
                    if(composite.numChildren>1 && c.paramNames.length==0) {
                        module_.addError(c, "Mixing named and un-named constructor arguments", true);
                    }
                    if(c.paramNames.contains(t.value)) {
                        module_.addError(t, "Duplicate call param name", true);
                    }
                    if(t.value=="this") {
                        module_.addError(t, "'this' cannot be used as a parameter name", true);
                    }
                    c.paramNames ~= t.value;
                    t.next;

                    /// :
                    t.skip(TT.COLON);

                    parse(t, composite);

                } else {
                    if (c.paramNames.length>0) {
                        module_.addError(c, "Mixing named and un-named constructor arguments", true);
                    }

                    parse(t, composite);
                }

                t.expect(TT.RBRACKET, TT.COMMA);
                if (t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RBRACKET);

            /// Move args to call and discard parenthesis
            while(composite.hasChildren) {
                c.add(composite.first());
            }
            composite.detach();
        }

        if(t.type==TT.LCURLY) {
            /// Groovy-style with closure arg at end
            /// func {}
            /// func() {}

            parse(t, c);
        }
    }
    void parseIdentifier(Tokens t, ASTNode parent) {

        auto id = makeNode!Identifier(t);
        parent.add(id);

        /// Two identifiers in a row means one was probably a type that we don't know about
        auto prev = id.prevSibling;
        if(prev && prev.isA!Identifier && parent.id==NodeID.TUPLE) {
            errorMissingType(module_, prev, prev.as!Identifier.name);
        }

        id.target = new Target(module_);
        id.name = t.value;
        t.next;
    }
    void parseParenthesis(Tokens t, ASTNode parent) {
        auto p = makeNode!Parenthesis(t);
        parent.add(p);

        t.skip(TT.LBRACKET);

        if(t.type==TT.RBRACKET) errorBadSyntax(module_, t, "Empty parenthesis");

        parse(t, p);

        t.skip(TT.RBRACKET);
    }
    ///
    /// literal_function ::= "{" [ arguments "->" ] { statement } "}"
    ///
    void parseLiteralFunction(Tokens t, ASTNode parent) {

        LiteralFunction f = makeNode!LiteralFunction(t);
        parent.add(f);

        auto params = makeNode!Parameters(t);
        f.add(params);

        auto type   = makeNode!FunctionType(t);
        type.params = params;
        f.type = Pointer.of(type, 1);

        /// {
        t.skip(TT.LCURLY);

        int arrow = t.findInScope(TT.RT_ARROW);
        if(arrow!=-1) {
            /// collect the args
            while(t.type!=TT.RT_ARROW) {

                varParser().parseParameter(t, params);

                t.expect(TT.RT_ARROW, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RT_ARROW);
        } else {
            /// no args
        }

        /// statements
        while(t.type != TT.RCURLY) {
            stmtParser().parse(t, f);
        }

        /// }
        t.skip(TT.RCURLY);

        /// If this is a closure we need to handle it differently
        if(!parent.isFunction) {
        //if(f.getContainer().id()==NodeID.LITERAL_FUNCTION) {

            string name = module_.makeTemporary("closure");
            auto var = f.getAncestor!Variable;
            if(var) {
                name ~= "_" ~ var.name;
            }

            auto closure = makeNode!Closure(t);
            closure.name = name;
            closure.add(f);

            module_.addClosure(closure);

            parent.add(closure);
        }
    }
    void parseUnary(Tokens t, ASTNode parent) {

        auto u = makeNode!Unary(t);
        parent.add(u);

        /// - ~ not
        if("not"==t.value) {
            u.op = Operator.BOOL_NOT;
        } else if(t.type==TT.TILDE) {
            u.op = Operator.BIT_NOT;
        } else if(t.type==TT.MINUS) {
            u.op = Operator.NEG;
        } else assert(false, "How did we get here?");

        t.next;

        parse(t, u);
    }
    ///
    /// literal_string ::= prefix '"' { char } '"'
    /// prefix ::= nothing | "r" | "u8"
    ///
    void parseLiteralString(Tokens t, ASTNode parent) {

        auto composite = makeNode!Composite(t);
        parent.add(composite);

        auto s = makeNode!LiteralString(t);

        /// todo - Concatenate strings here if possible
        string text = t.value;
        t.next;

        assert(text.length>1);
        if(text[0]=='\"') {
            /// Default UTF8 string
            assert(text[0]=='\"' && text[$-1]=='\"');
            text = text[1..$-1];
            s.enc = LiteralString.Encoding.U8;
        } else if(text[0]=='r') {
            /// Raw string
            assert(text[1]=='\"' && text[$-1]=='\"');
            text = text[2..$-1];
            s.enc = LiteralString.Encoding.RAW;
        } else {
            assert(false, "How did we get here? string is %s".format(text));
        }

        s.value = text;

        module_.addLiteralString(s);

        auto b = module_.builder(parent);

        /// Create an alloca
        auto var = makeNode!Variable(t);
        var.name = module_.makeTemporary("str");
        var.type = typeFinder.findType("string", parent);
        composite.add(var);

        /// Call string.new(this, byte*, int, int)

        Call call    = b.call("new", null);
        auto thisPtr = b.addressOf(b.identifier(var.name));
        call.add(thisPtr);
        call.add(s);
        call.add(LiteralNumber.makeConst(0, TYPE_INT));
        call.add(LiteralNumber.makeConst(s.calculateLength(), TYPE_INT));

        auto dot = b.dot(b.identifier(var.name), call);

        auto valueof = b.valueOf(dot);
        composite.add(valueof);
    }
    ///
    /// constructor ::= identifier "(" { cexpr [ "," cexpr ] } ")"
    /// cexpr :: expression | paramname ":" expression
    ///
    void parseConstructor(Tokens t, ASTNode parent) {
        import common : contains;
        /// S(...)
        ///    Variable _temp (type=S)
        ///    Dot
        ///       _temp
        ///       Call new
        ///          addressof(_temp)
        ///    _temp

        /// S*(...)
        ///    Variable _temp (type=S*)
        ///    _temp = calloc
        ///    Dot
        ///       _temp
        ///       Call new
        ///          _temp
        ///    _temp
        ///
        auto con = makeNode!Constructor(t);
        parent.add(con);

        auto b = module_.builder(con);

        /// type
        con.type = typeParser().parse(t, parent);

        if(!con.type) {
            errorMissingType(module_, t, t.value);
        }
        if(!con.type.isAlias && !con.type.isStruct) {
            errorBadSyntax(module_, t, "Expecting a struct name here");
        }

        Variable makeVariable() {
            auto prefix = con.getName();
            if(prefix.contains("__")) prefix = "constructor";
            return b.variable(module_.makeTemporary(prefix), con.type, false);
        }

        /// Prepare the call to new(this, ...)
        auto call       = b.call("new", null);
        Expression expr = call;
        Variable var    = makeVariable();

        /// variable _temp
        con.add(var);

        /// allocate memory
        if(con.type.isPtr) {
            /// Heap calloc

            /// _temp = calloc
            auto calloc  = makeNode!Calloc(t);
            calloc.valueType = con.type.getValueType;
            con.add(b.assign(b.identifier(var.name), calloc));

            call.add(b.identifier(var.name));
        } else {
            /// Stack alloca
            call.add(b.addressOf(b.identifier(var.name)));
        }
        /// Dot
        ///    _temp
        ///    Call new
        ///       _temp
        auto dot = b.dot(b.identifier(var), call);
        con.add(dot);

        /// _temp
        con.add(b.identifier(var));

        /// (
        t.skip(TT.LBRACKET);

        /// Add args to a Composite to act as a ceiling so that
        /// the operator precedence never moves them above the call
        auto composite = Composite.make(t, Composite.Usage.STANDARD);
        call.add(composite);

        while(t.type!=TT.RBRACKET) {

            if(t.peek(1).type==TT.COLON) {
                /// paramname = expr

                if(composite.numChildren>1 && call.paramNames.length==0) {
                    module_.addError(con, "Mixing named and un-named constructor arguments", true);
                }

                /// Add the implicit 'this' param
                if(composite.numChildren==0) {
                    call.paramNames ~= "this";
                }

                if(call.paramNames.contains(t.value)) {
                    module_.addError(t, "Duplicate call param name", true);
                }
                if(t.value=="this") {
                    module_.addError(t, "'this' cannot be used as a parameter name", true);
                }

                call.paramNames ~= t.value;
                t.next;

                t.skip(TT.COLON);

                parse(t, composite);

            } else {
                if(call.paramNames.length>0) {
                    module_.addError(con, "Mixing named and un-named constructor arguments", true);
                }
                parse(t, composite);
            }

            t.expect(TT.COMMA, TT.RBRACKET);
            if(t.type==TT.COMMA) t.next;
        }
        /// )
        t.skip(TT.RBRACKET);

        /// Move args to call and discard parenthesis
        while(composite.hasChildren) {
            call.add(composite.first());
        }
        composite.detach();
    }
    void parseAddressOf(Tokens t, ASTNode parent) {

        auto a = makeNode!AddressOf(t);
        parent.add(a);

        t.skip(TT.AMPERSAND);

        parse(t, a);
    }
    void parseValueOf(Tokens t, ASTNode parent) {

        auto v = makeNode!ValueOf(t);
        parent.add(v);

        t.skip(TT.ASTERISK);

        parse(t, v);
    }
    ///
    /// if   ::= "if" "(" [ var  ";" ] expression ")" then [ else ]
    /// then ::= [ "{" ] {statement} [ "}" ]
    /// else ::= "else" [ "{" ] {statement}  [ "}" ]
    ///
    void parseIf(Tokens t, ASTNode parent) {
        auto i = makeNode!If(t);
        parent.add(i);

        /// if
        t.skip("if");

        /// (
        t.skip(TT.LBRACKET);

        /// possible init expressions
        auto inits = Composite.make(t, Composite.Usage.PERMANENT);
        i.add(inits);

        bool hasInits() {
            auto end = t.findInScope(TT.RBRACKET);
            auto sc  = t.findInScope(TT.SEMICOLON);
            return sc!=-1 && end!=-1 && sc < end;
        }

        if(hasInits()) {
            while(t.type!=TT.SEMICOLON) {

                stmtParser().parse(t, inits);

                t.expect(TT.COMMA, TT.SEMICOLON);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.SEMICOLON);
        }
        /// condition
        parse(t, i);

        /// )
        t.skip(TT.RBRACKET);

        auto then = Composite.make(t, Composite.Usage.PERMANENT);
        i.add(then);

        /// then block
        if(t.type==TT.LCURLY) {
            t.skip(TT.LCURLY);

            while(t.type!=TT.RCURLY) {
                stmtParser().parse(t, then);
            }
            t.skip(TT.RCURLY);

        } else {
            stmtParser().parse(t, then);
        }

        /// else block
        if(t.isKeyword("else")) {
            t.skip("else");

            auto else_ = Composite.make(t, Composite.Usage.PERMANENT);
            i.add(else_);

            if(t.type==TT.LCURLY) {
                t.skip(TT.LCURLY);

                while(t.type!=TT.RCURLY) {
                    stmtParser().parse(t, else_);
                }
                t.skip(TT.RCURLY);

            } else {
                stmtParser().parse(t, else_);
            }
        }
    }
    ///
    /// select_expr ::= "select" "(" [ { stmt } ";" ] expr ")" "{" { case } else_case "}"
    /// case        ::= const_expr ":" (expr | "{" expr "}" )
    /// else_case   ::= "else"     ":" (expr | "{" expr "}" )
    ///
    /// select    ::= "select" "{" { case } else_case "}"
    /// case      ::= expr   ":" ( expr | "{" expr "}" )
    /// else_case ::= "else" ":" ( expr | "{" expr "}" )
    ///
    void parseSelect(Tokens t, ASTNode parent) {
        auto s = makeNode!Select(t);
        parent.add(s);

        /// select
        t.skip("select");

        if(t.type==TT.LBRACKET) {
            ///
            /// select switch
            ///
            s.isSwitch = true;

            /// (
            t.skip(TT.LBRACKET);

            /// possible init expressions
            auto inits = Composite.make(t, Composite.Usage.PERMANENT);
            s.add(inits);

            bool hasInits() {
                auto end = t.findInScope(TT.RBRACKET);
                auto sc  = t.findInScope(TT.SEMICOLON);
                return sc!=-1 && end!=-1 && sc < end;
            }

            if(hasInits()) {
                while(t.type!=TT.SEMICOLON) {

                    stmtParser().parse(t, inits);

                    t.expect(TT.COMMA, TT.SEMICOLON);
                    if(t.type==TT.COMMA) t.next;
                }
                t.skip(TT.SEMICOLON);
            }

            /// value
            parse(t, s);

            /// )
            t.skip(TT.RBRACKET);
        }
        /// {
        t.skip(TT.LCURLY);

        int countDefaults = 0;
        int countCases    = 0;

        ///
        /// Cases
        ///
        void parseCase() {
            auto comp = Composite.make(t, Composite.Usage.PERMANENT);

            if(t.isKeyword("else")) {
                t.next;
                s.add(comp);
                countDefaults++;
                t.skip(TT.COLON);
            } else {
                countCases++;
                auto case_ = makeNode!Case(t);
                s.add(case_);

                while(t.type!=TT.COLON) {
                    /// expr
                    parse(t, case_);

                    t.expect(TT.COMMA, TT.COLON);
                    if(t.type==TT.COMMA) {
                        if(!s.isSwitch) {
                            module_.addError(t, "Boolean-style Select can not have multiple expressions", true);
                        }
                        t.next;
                    }
                }

                t.skip(TT.COLON);

                case_.add(comp);
            }

            if(t.type==TT.LCURLY) {
                /// Multiple statements
                t.skip(TT.LCURLY);

                while(t.type!=TT.RCURLY) {
                    stmtParser().parse(t, comp);
                }
                t.skip(TT.RCURLY);
            } else {
                /// Must be just a single statement
                stmtParser().parse(t, comp);
            }
        }
        while(t.type!=TT.RCURLY) {
            parseCase();
        }
        /// }
        t.skip(TT.RCURLY);

        if(countDefaults == 0) {
            module_.addError(s, "Select must have an else clause", true);
        } else if(countDefaults > 1) {
            module_.addError(s, "Select can only have one else clause", true);
        }
        if(countCases==0) {
            module_.addError(s, "Select must have at least one non-default clause", true);
        }
    }
    ///
    /// literal_tuple ::= "[" { [name ":"] expression } [ "," [name ":"] expression ] "]"
    ///
    void parseLiteralTuple(Tokens t, ASTNode parent) {
        auto e = makeNode!LiteralTuple(t);
        parent.add(e);

        /// [
        t.skip(TT.LSQBRACKET);

        /// expression list or
        /// name : expression list
        while(t.type!=TT.RSQBRACKET) {

            if(t.peek(1).type==TT.COLON) {
                /// name = expression
                if(e.hasChildren && e.names.length==0) {
                    module_.addError(t, "Tuple literals must be either all named or all unnamed", true);
                }

                e.names ~= t.value;
                t.next;
                t.skip(TT.COLON);

                parse(t, e);
            } else {
                /// expression
                if(e.names.length>0) {
                    module_.addError(t, "Tuple literals must be either all named or all unnamed", true);
                }

                parse(t, e);
            }
            t.expect(TT.RSQBRACKET, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RSQBRACKET);

        /// Consume "as tuple"
        if(t.isKeyword("as") && t.peek(1).value=="tuple") {
            t.next(2);
        }
    }
    ///
    /// literal_array ::= "[:" expression { "," expression } "]"
    ///
    void parseLiteralArray(Tokens t, ASTNode parent) {
        auto e = makeNode!LiteralArray(t);
        parent.add(e);

        /// [:
        t.skip(TT.LSQBRACKET);
        t.skip(TT.COLON);

        /// elements
        while(t.type!=TT.RSQBRACKET) {

            parse(t, e);

            t.expect(TT.RSQBRACKET, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RSQBRACKET);
    }
    ///
    /// expr_list := "[" { expr { "," expr } } "]"
    ///
    void parseLiteralExprList(Tokens t, ASTNode parent) {
        auto e = makeNode!LiteralExpressionList(t);
        parent.add(e);

        /// [
        t.skip(TT.LSQBRACKET);

        /// elements
        while(t.type!=TT.RSQBRACKET) {

            parse(t, e);

            t.expect(TT.RSQBRACKET, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }

        /// ]
        t.skip(TT.RSQBRACKET);
    }
    void parseModuleAlias(Tokens t, ASTNode parent, Import imp) {

        auto alias_ = makeNode!ModuleAlias(t);
        alias_.mod  = imp.mod;
        alias_.imp  = imp;

        parent.add(alias_);

        t.next;
    }
    void parseBuiltinFunc(Tokens t, ASTNode parent) {
        auto bif = makeNode!BuiltinFunc(t);
        parent.add(bif);

        bif.name = t.value;
        t.next;

        /// (
        t.skip(TT.LBRACKET);

        /// Add args to a Composite to act as a ceiling so that
        /// the operator precedence never moves them above the call
        auto composite = Composite.make(t, Composite.Usage.STANDARD);
        bif.add(composite);

        while(t.type!=TT.RBRACKET) {
            parse(t, composite);
        }

        t.skip(TT.RBRACKET);
        /// )
    }
}

