module ppl2.parse.parse_expression;

import ppl2.internal;

final class ExpressionParser {
private:
    Module module_;

    auto typeParser()   { return module_.typeParser; }
    auto typeDetector() { return module_.typeDetector; }
    auto stmtParser()   { return module_.stmtParser; }
    auto varParser()    { return module_.varParser; }
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

        //if(module_.canonicalName=="test") dd("lhs", t.get, "parent=", parent.id);

        /// Starts with a type
        int eot = typeDetector().endOffset(t, parent);
        if(eot!=-1) {
            auto nextTok = t.peek(eot+1);

            if(nextTok.value=="is" || t.peek(-1).value=="is") {
                parseTypeExpr(t, parent);
                return;
            }
            if(t.peek(-1).value=="as") {
                parseTypeExpr(t, parent);
                return;
            }
            if(nextTok.type==TT.LBRACKET) {
                parseConstructor(t, parent);
                return;
            }
            if(t.peek(-2).value=="is" && t.peek(-1).value=="not") {
                parseTypeExpr(t, parent);
                return;
            }
            if(nextTok.type==TT.DOT || nextTok.type==TT.DBL_COLON) {
                parseTypeExpr(t, parent);
                return;
            }
        }

        /// Simple literals
        if(t.type==TT.NUMBER || t.type==TT.CHAR || "true"==t.value || "false"==t.value || "null"==t.value) {
            parseLiteral(t, parent);
            return;
        } else if("if"==t.value) {
            parseIf(t, parent);
            return;
        } else if(t.value=="not") {
            parseUnary(t, parent);
            return;
        } else if(t.value=="operator") {
            parseCall(t, parent);
            return;
        }

        /// name (
        /// name.name {
        /// name <
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
            auto node = parent.hasChildren ? parent.last : parent;
            auto imp = findImportByAlias(t.value, node);
            if(imp) {
                parseModuleAlias(t, parent, imp);
                return;
            }

            parseIdentifier(t, parent);
            return;
        }

        /// Everything else
        switch(t.type) {
            case TT.STRING:
                parseLiteralString(t, parent);
                break;
            case TT.LBRACKET:
                parseParenthesis(t, parent);
                break;
            case TT.LSQBRACKET:


                if(t.peek(1).type==TT.COLON) {
                    /// [:
                    parseLiteralArray(t, parent);
                } else {
                    /// [
                    parseLiteralStruct(t, parent);
                }
                break;
            case TT.LCURLY:
                parseLiteralFunction(t, parent);
                break;
            case TT.MINUS:
            case TT.TILDE:
                parseUnary(t, parent);
                break;
            case TT.AMPERSAND:
                parseAddressOf(t, parent);
                break;
            case TT.AT:
                parseValueOf(t, parent);
                break;
            case TT.EXCLAMATION:
                errorBadSyntax(module_, t, "Did you mean 'not'");
                break;
            default:
                //errorBadSyntax(t, "Syntax error");
                writefln("BAD LHS %s", t.get);
                parent.getModule.dumpToConsole();
                module_.addError(t, "Bad LHS", false);
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
                case TT.AT:
                    /// end of expression
                    return;
                case TT.PLUS:
                case TT.MINUS:
                case TT.DIV:
                case TT.PERCENT:
                case TT.ASTERISK:
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

                    /// AnonStruct or ArrayStruct
                    if(typeDetector().isType(t, parent, 1)) {
                        return;
                    }
                    parent = attachAndRead(t, parent, parseIndex(t, parent), false);
                    break;
                case TT.DOT:
                case TT.DBL_COLON:
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
            d.dotType = Dot.DotType.MEMBER;
        } else {
            t.skip(TT.DBL_COLON);
            d.dotType = Dot.DotType.STATIC;
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

                if (t.peek(1).type==TT.EQUALS) {
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

                    t.skip(TT.EQUALS);

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
        if(prev && prev.isA!Identifier && parent.id==NodeID.ANON_STRUCT) {
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
        f.type = PtrType.of(type, 1);

        t.skip(TT.LCURLY);

        int arrow = t.findInScope(TT.RT_ARROW);
        if(arrow!=-1) {
            /// collect the args
            while(t.type!=TT.RT_ARROW) {

                varParser().parse(t, params);

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

        /// Call string.new(this, byte*, int)

        Call call    = b.call("new", null);
        auto thisPtr = b.addressOf(b.identifier(var.name));
        call.add(thisPtr);
        call.add(s);
        call.add(LiteralNumber.makeConst(s.calculateLength(), TYPE_INT));

        auto dot = b.dot(b.identifier(var.name), call);

        auto valueof = b.valueOf(dot);
        composite.add(valueof);
    }
    ///
    /// constructor ::= identifier "(" { cexpr [ "," cexpr ] } ")"
    /// cexpr :: expression | paramname "=" expression
    ///
    void parseConstructor(Tokens t, ASTNode parent) {
        /// S(...)
        ///    Variable _temp
        ///    ValueOf
        ///       Dot
        ///          _temp
        ///          Call new
        ///             this*
        ///
        /// S*(...)
        ///       Dot
        ///          TypeExpr (S*)
        ///          Call new
        ///             malloc
        ///
        auto con = makeNode!Constructor(t);
        parent.add(con);

        auto b = module_.builder(con);

        /// type
        con.type = typeParser().parse(t, parent);
        if(!con.type) {
            errorMissingType(module_, t, t.value);
        }
        if(!con.type.isAlias && !con.type.isNamedStruct) {
            errorBadSyntax(module_, t, "Expecting a struct name here");
        }

        /// Prepare the call to new(this, ...)
        auto call       = b.call("new", null);
        Expression expr = call;

        Expression thisPtr;
        /// allocate memory
        if(con.type.isPtr) {
            /// Heap calloc
            auto calloc  = makeNode!Calloc(t);
            calloc.valueType = con.type.getValueType;

            thisPtr = calloc;

            expr = b.dot(b.typeExpr(con.type), call);
        } else {
            /// Stack alloca
            import common : contains;
            auto prefix = con.getName();
            if(prefix.contains("__")) prefix = "constructor";
            auto var  = b.variable(module_.makeTemporary(prefix), con.type, false);
            con.add(var);

            thisPtr = b.addressOf(b.identifier(var.name));

            auto dot = b.dot(b.identifier(var), call);
            expr = b.valueOf(dot);
        }
        call.add(thisPtr);

        con.add(expr);

        /// (
        t.skip(TT.LBRACKET);

        import common : contains;

        /// Add args to a Composite to act as a ceiling so that
        /// the operator precedence never moves them above the call
        auto composite = Composite.make(t, Composite.Usage.STANDARD);
        call.add(composite);

        while(t.type!=TT.RBRACKET) {

            if(t.peek(1).type==TT.EQUALS) {
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

                t.skip(TT.EQUALS);

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

        t.skip(TT.AT);

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
    /// literal_struct ::= "[" { [name "="] expression } [ "," [name "="] expression ] "]"
    ///
    void parseLiteralStruct(Tokens t, ASTNode parent) {
        auto e = makeNode!LiteralStruct(t);
        parent.add(e);

        /// [
        t.skip(TT.LSQBRACKET);

        /// expression list or
        /// name = expression list
        while(t.type!=TT.RSQBRACKET) {
            if(t.peek(1).type==TT.EQUALS) {
                /// name = expression
                if(e.hasChildren && e.names.length==0) {
                    module_.addError(t, "Struct literals must be either all named or all unnamed", true);
                }

                e.names ~= t.value;
                t.next;
                t.skip(TT.EQUALS);

                parse(t, e);
            } else {
                /// expression
                if(e.names.length>0) {
                    module_.addError(t, "Struct literals must be either all named or all unnamed", true);
                }

                parse(t, e);
            }
            t.expect(TT.RSQBRACKET, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RSQBRACKET);
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
    void parseModuleAlias(Tokens t, ASTNode parent, Import imp) {

        auto alias_ = makeNode!ModuleAlias(t);
        alias_.mod  = imp.mod;
        alias_.imp  = imp;

        parent.add(alias_);

        t.next;
    }
}

