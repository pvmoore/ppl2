module ppl2.parse.parse_expression;

import ppl2.internal;

final class ExpressionParser {
private:
    Module module_;

    TypeParser typeParser() { return module_.typeParser; }
    TypeDetector typeDetector() { return module_.typeDetector; }
    StatementParser stmtParser() { return module_.stmtParser; }
    VariableParser varParser() { return module_.varParser; }
    NodeBuilder builder() { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }

    void parse(TokenNavigator t, ASTNode parent) {
        //log("Expression: parse---------------------------- START");
        //dd("expression");

        parseLHS(t, parent);
        parseRHS(t, parent);

        //log("Expression: parse---------------------------- END");
    }
private:
    void parseLHS(TokenNavigator t, ASTNode parent) {

        int eot = typeDetector().endOffset(t, parent);
        if(eot!=-1) {
            /// This is a type

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
                parseStructConstructor(t, parent);
                return;
            }
            if(t.peek(-2).value=="is" && t.peek(-1).value=="not") {
                parseTypeExpr(t, parent);
                return;
            }
            if(nextTok.type==TT.DOT) {
                parseTypeExpr(t, parent);
                return;
            }
        }

        if(t.type==TT.NUMBER || t.type==TT.CHAR || "true"==t.value || "false"==t.value || "null"==t.value) {
            parseLiteral(t, parent);
        } else if("if"==t.value) {
            parseIf(t, parent);
        } else if(t.value=="not") {
            parseUnary(t, parent);
        } else switch(t.type) {
            case TT.STRING:
                parseLiteralString(t, parent);
                break;
            case TT.IDENTIFIER:
                if(t.peek(1).type==TT.LBRACKET) {
                    parseCall(t, parent);
                } else {
                    parseIdentifier(t, parent);
                }
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
            case TT.LANGLE:
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
            default:
                writefln("BAD LHS %s", t.get);
                parent.getModule.dumpToConsole();
                throw new CompilerError(Err.BAD_LHS_EXPR, t, "Bad LHS");
        }
    }
    void parseRHS(TokenNavigator t, ASTNode parent) {

        while(true) {
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
                case TT.LSQBRACKET:
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
                case TT.AMPERSAND:
                case TT.HAT:
                case TT.PIPE:
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
                case TT.BOOL_NE:
                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.COLON:
                    parent = attachAndRead(t, parent, parseIndex(t));
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
                    throw new CompilerError(Err.BAD_RHS_EXPR, t, "Bad RHS");
            }
        }
    }
    Expression attachAndRead(TokenNavigator t, ASTNode parent, Expression newExpr) {
        ASTNode prev = parent;

        ///
        /// Swap expressions according to operator precedence
        ///
        const doPrecedenceCheck = prev.isA!Expression && !prev.isCall && !prev.isIf;
        if(doPrecedenceCheck) {

            /// Ensure two expressions in a row do not have the same priority
            /// as this could lead to ambiguous results
            bool isAmbiguous = parent.isExpression &&
                              (newExpr.priority == parent.as!Expression.priority);

            bool binary = (newExpr.isBinary && parent.isBinary);
            bool as     = (newExpr.isAs && parent.isAs);

            if(isAmbiguous && (binary || as)) {
                errorAmbiguousExpr(parent);
            }

            /// Adjust to account for operator precedence
            Expression prevExpr = prev.as!Expression;
            while(prevExpr.parent && newExpr.priority >= prevExpr.priority) {

                if(!prevExpr.parent.isExpression) {
                    prev = prevExpr.parent;
                    break;
                }

                prevExpr = prevExpr.parent.as!Expression;
                prev     = prevExpr;
            }
        }

        newExpr.addToEnd(prev.last);
        prev.addToEnd(newExpr);

        parseLHS(t, newExpr);

        return newExpr;
    }
    ///
    /// binary_expr ::= expression operator expression
    /// operator ::= "=" | "+" | "-" etc...
    ///
    ///
    Expression parseBinary(TokenNavigator t) {

        auto b = makeNode!Binary(t);

        if("and"==t.value) {
            b.op = Operator.BOOL_AND;
        } else if("or"==t.value) {
            b.op = Operator.BOOL_OR;
        } else {
            b.op = parseOperator(t);
        }

        t.next;

        return b;
    }
    ///
    /// dot_expr ::= expression "." expression
    ///
    Expression parseDot(TokenNavigator t) {

        auto d = makeNode!Dot(t);

        t.skip(TT.DOT);

        return d;
    }
    Expression parseIndex(TokenNavigator t) {

        auto i = makeNode!Index(t);

        t.skip(TT.COLON);

        return i;
    }
    ///
    /// expression "as" type
    ///
    Expression parseAs(TokenNavigator t) {

        auto a = makeNode!As(t);

        t.skip("as");

        return a;
    }
    Expression parseIs(TokenNavigator t) {
        auto i = makeNode!Is(t);

        t.skip("is");

        if(t.value=="not") {
            t.skip("not");
            i.negate = true;
        }

        return i;
    }
    void parseTypeExpr(TokenNavigator t, ASTNode parent) {
        auto e = makeNode!TypeExpr(t);
        parent.addToEnd(e);

        e.type = typeParser().parse(t, e);

        if(e.type is null) {
            errorMissingType(t, t.value);
        }
    }
    ///
    /// literal_number |
    /// literal_string |
    /// literal_char
    ///
    void parseLiteral(TokenNavigator t, ASTNode parent) {
        Expression e;

        if(t.type==TT.NUMBER || t.type==TT.CHAR || t.value=="true" || t.value=="false") {
            auto lit = makeNode!LiteralNumber(t);
            lit.str = t.value;
            e = lit;
            parent.addToEnd(e);
            lit.determineType();
            t.next;
        } else if("null"==t.value) {
            e = makeNode!LiteralNull(t);
            parent.addToEnd(e);
            t.next;
        } else {
            assert(false, "How did we get here?");
        }
    }
    ///
    /// call_expression::= identifier "(" [ expression ] { "," expression } ")"
    ///
    void parseCall(TokenNavigator t, ASTNode parent) {

        auto c = makeNode!Call(t);
        parent.addToEnd(c);

        c.target = new Target(module_);
        c.name = t.value;
        t.next;

        if(c.name=="new") {
            ///
            /// This is a construtor call. We don't currently allow this
            ///
            throw new CompilerError(Err.CALL_CONSTRUCTOR_CALLS_DISALLOWED, c,
                "Explicit constructor calls not allowed");
        }

        t.skip(TT.LBRACKET);

        import common : contains;

        while(t.type!=TT.RBRACKET) {

            if(t.peek(1).type==TT.EQUALS) {
                /// paramname = expr
                if(c.numArgs>1 && c.paramNames.length==0) {
                    throw new CompilerError(Err.CALL_MIXING_NAMED_AND_UNNAMED, c,
                        "Mixing named and un-named constructor arguments");
                }
                if(c.paramNames.contains(t.value)) {
                    throw new CompilerError(Err.CALL_DUPLICATE_PARAM_NAME, t, "Duplicate call param name");
                }
                if(t.value=="this") {
                    throw new CompilerError(Err.CALL_PARAM_CAN_NOT_BE_CALLED_THIS, t,
                        "'this' cannot be used as a parameter name");
                }
                c.paramNames ~= t.value;
                t.next;

                t.skip(TT.EQUALS);

                parse(t, c);

            } else {
                if(c.paramNames.length>0) {
                    throw new CompilerError(Err.CALL_MIXING_NAMED_AND_UNNAMED, c,
                        "Mixing named and un-named constructor arguments");
                }

                parse(t, c);
            }

            t.expect(TT.RBRACKET, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RBRACKET);
    }
    void parseIdentifier(TokenNavigator t, ASTNode parent) {

        auto id = makeNode!Identifier(t);
        parent.addToEnd(id);

        /// Two identifiers in a row means one was probably a type that we don't know about
        auto prev = id.prevSibling;
        if(prev && prev.isA!Identifier && parent.id==NodeID.ANON_STRUCT) {
            errorMissingType(prev, prev.as!Identifier.name);
        }

        id.target = new Target(module_);
        id.name = t.value;
        t.next;
    }
    void parseParenthesis(TokenNavigator t, ASTNode parent) {
        auto p = makeNode!Parenthesis(t);
        parent.addToEnd(p);

        t.skip(TT.LBRACKET);

        parse(t, p);

        t.skip(TT.RBRACKET);
    }
    ///
    /// literal_function ::= [template_args] "{" [ arguments "->" ] { statement } "}"
    ///
    void parseLiteralFunction(TokenNavigator t, ASTNode parent) {
        if(t.type==TT.LANGLE) {
            /// Template function - just gather the args and tokens
            auto f = makeNode!LiteralFunctionTemplate(t);
            f.type = makeNode!FunctionType(t);
            parent.addToEnd(f);

            /// < .. >
            t.skip(TT.LANGLE);
            while(t.type!=TT.RANGLE) {
                f.templateArgNames ~= t.value;
                t.next;
                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            t.expect(TT.LCURLY);
            int start = t.index;
            int end   = t.findEndOfBlock(TT.LCURLY);
            f.tokens = t.get(start, start+end).dup;

            t.next(end+1);
        } else {
            /// This is a concrete LiteralFunction
            LiteralFunction f = makeNode!LiteralFunction(t);
            parent.addToEnd(f);

            auto params = makeNode!Parameters(t);
            f.addToEnd(params);

            auto type   = makeNode!FunctionType(t);
            type.params = params;
            f.type = PtrType.of(type, 1);

            t.skip(TT.LCURLY);

            int arrow = t.findInCurrentScope(TT.RT_ARROW);
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
                if(parent.isInitialiser) {
                    name ~= "_" ~ parent.as!Initialiser.var.name;
                }

                auto closure = makeNode!Closure(t);
                closure.name = name;
                closure.addToEnd(f);

                module_.addClosure(closure);

                parent.addToEnd(closure);
            }
        }
    }
    ///
    /// literal_struct ::= "[" { [name "="] expression } [ "," [name "="] expression ] "]"
    ///
    void parseLiteralStruct(TokenNavigator t, ASTNode parent) {
        auto e = makeNode!LiteralStruct(t);
        parent.addToEnd(e);

        /// [
        t.skip(TT.LSQBRACKET);

        /// expression list or
        /// name = expression list
        while(t.type!=TT.RSQBRACKET) {
            if(t.peek(1).type==TT.EQUALS) {
                /// name = expression
                if(e.hasChildren && e.names.length==0) errorStructLiteralMixedInitialisation(t);

                e.names ~= t.value;
                t.next;
                t.skip(TT.EQUALS);

                parse(t, e);
            } else {
                /// expression
                if(e.names.length>0) errorStructLiteralMixedInitialisation(t);

                parse(t, e);
            }
            t.expect(TT.RSQBRACKET, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RSQBRACKET);
    }
    ///
    /// literal_array ::= "[:" [digits"="] expression { "," [digits"="] expression } "]"
    ///
    void parseLiteralArray(TokenNavigator t, ASTNode parent) {
        auto e = makeNode!LiteralArray(t);
        parent.addToEnd(e);

        /// [:
        t.skip(TT.LSQBRACKET);
        t.skip(TT.COLON);

        /// elements
        while(t.type!=TT.RSQBRACKET) {

            if(t.peek(1).type==TT.EQUALS) {
                /// number = expression
                if(e.hasChildren && !e.isIndexBased) errorArrayLiteralMixedInitialisation(t);
                e.isIndexBased = true;

                /// index = value (Binary = )
                parse(t, e);
                if(!e.last.isA!Binary) errorBadSyntax(e.last, "Syntax error. Expecting binary =");

                /// Split binary into 2 expressions
                auto b = e.last.as!Binary;
                e.remove(b);
                e.addToEnd(b.left);
                e.addToEnd(b.right);

            } else {
                if(e.isIndexBased) errorArrayLiteralMixedInitialisation(t);

                /// value
                parse(t, e);
            }

            t.expect(TT.RSQBRACKET, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RSQBRACKET);
    }
    void parseUnary(TokenNavigator t, ASTNode parent) {

        auto u = makeNode!Unary(t);
        parent.addToEnd(u);

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
    void parseLiteralString(TokenNavigator t, ASTNode parent) {

        auto composite = makeNode!Composite(t);
        parent.addToEnd(composite);

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
        var.type = findType("string", parent);
        composite.addToEnd(var);

        /// Call string.new(this, byte*, int)

        Call call    = b.call("new", null);
        auto thisPtr = b.addressOf(b.identifier(var.name));
        call.addToEnd(thisPtr);
        call.addToEnd(s);
        call.addToEnd(LiteralNumber.makeConst(s.calculateLength(), TYPE_INT));

        auto dot = b.dot(b.identifier(var.name), call);

        auto valueof = b.valueOf(dot);
        composite.addToEnd(valueof);
    }
    ///
    /// constructor ::= identifier "(" { cexpr [ "," cexpr ] } ")"
    /// cexpr :: expression | paramname "=" expression
    ///
    void parseStructConstructor(TokenNavigator t, ASTNode parent) {
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
        parent.addToEnd(con);

        auto b = module_.builder(con);

        /// type
        con.type = typeParser().parse(t, parent);
        if(!con.type) {
            errorMissingType(t, t.value);
        }
        if(!con.type.isDefine && !con.type.isNamedStruct) {
            errorBadSyntax(t, "Expecting a struct name here");
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
            auto var  = b.variable(module_.makeTemporary(con.getName()), con.type, false);
            con.addToEnd(var);

            thisPtr = b.addressOf(b.identifier(var.name));

            auto dot = b.dot(b.identifier(var), call);
            expr = b.valueOf(dot);
        }
        call.addToEnd(thisPtr);

        con.addToEnd(expr);

        /// (
        t.skip(TT.LBRACKET);

        import common : contains;

        while(t.type!=TT.RBRACKET) {

            if(t.peek(1).type==TT.EQUALS) {
                /// paramname = expr

                if(call.numArgs>1 && call.paramNames.length==0) {
                    throw new CompilerError(Err.CALL_MIXING_NAMED_AND_UNNAMED, con,
                        "Mixing named and un-named constructor arguments");
                }

                /// Add the implicit 'this' param
                if(call.numArgs==1) {
                    call.paramNames ~= "this";
                }

                if(call.paramNames.contains(t.value)) {
                    throw new CompilerError(Err.CALL_DUPLICATE_PARAM_NAME, t, "Duplicate call param name");
                }
                if(t.value=="this") {
                    throw new CompilerError(Err.CALL_PARAM_CAN_NOT_BE_CALLED_THIS, t,
                        "'this' cannot be used as a parameter name");
                }

                call.paramNames ~= t.value;
                t.next;

                t.skip(TT.EQUALS);

                parse(t, call);

            } else {
                if(call.paramNames.length>0) {
                    throw new CompilerError(Err.CALL_MIXING_NAMED_AND_UNNAMED, con,
                        "Mixing named and un-named constructor arguments");
                }
                parse(t, call);
            }

            t.expect(TT.COMMA, TT.RBRACKET);
            if(t.type==TT.COMMA) t.next;
        }
        /// )
        t.skip(TT.RBRACKET);
    }
    void parseAddressOf(TokenNavigator t, ASTNode parent) {

        auto a = makeNode!AddressOf(t);
        parent.addToEnd(a);

        t.skip(TT.AMPERSAND);

        parse(t, a);
    }
    void parseValueOf(TokenNavigator t, ASTNode parent) {

        auto v = makeNode!ValueOf(t);
        parent.addToEnd(v);

        t.skip(TT.AT);

        parse(t, v);
    }
    ///
    /// if   ::= "if" "(" [ var  ";" ] expression ")" then [ else ]
    /// then ::= [ "{" ] {statement} [ "}" ]
    /// else ::= "else" [ "{" ] {statement}  [ "}" ]
    ///
    void parseIf(TokenNavigator t, ASTNode parent) {
        auto i = makeNode!If(t);
        parent.addToEnd(i);

        /// if
        t.skip("if");

        /// (
        t.skip(TT.LBRACKET);

        /// possible init expressions
        auto inits = Composite.make(t, true);
        i.addToEnd(inits);

        bool hasInits() {
            auto end = t.findInCurrentScope(TT.RBRACKET);
            auto sc  = t.findInCurrentScope(TT.SEMICOLON);
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

        auto then = Composite.make(t, true);
        i.addToEnd(then);

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

            auto else_ = Composite.make(t, true);
            i.addToEnd(else_);

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
}

