module ppl2.parse.parse_expression;

import ppl2.internal;

final class ExpressionParser {
private:
    Module module_;

    TypeParser typeParser() { return module_.typeParser; }
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
    /**
     *  lhs ::= literal_number
     *          literal_string
     *          literal_char
     *          literal_function
     *          literal_struct
     *          call "(  { expression "}"
     *          identifier
     *          parenthesis
     */
    void parseLHS(TokenNavigator t, ASTNode parent) {

        if(t.peek(-1).value=="as") {
            parseTypeExpr(t, parent);
        } else if(t.value=="not") {
            parseUnary(t, parent);
        } else if(t.value=="assert") {
            parseAssert(t, parent);
        } else switch(t.type) {
            case TT.NUMBER:
            case TT.CHAR:
                parseLiteral(t, parent);
                break;
            case TT.STRING:
                parseLiteralString(t, parent);
                break;
            case TT.IDENTIFIER:
                if("true"==t.value || "false"==t.value || "null"==t.value) {
                    parseLiteral(t, parent);
                } else if(t.peek(1).type==TT.LBRACKET) {
                    if(typeParser().isType(t, parent)) {
                        parseStructConstructor(t, parent);
                    } else {
                        parseCall(t, parent);
                    }
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
            case TT.HASH:
                parseMetaFunction(t, parent);
                break;
            default:
                parent.getModule.dumpToConsole();
                throw new CompilerError(Err.BAD_LHS_EXPR, t, "Bad LHS");
        }
    }
    void parseRHS(TokenNavigator t, ASTNode parent) {

        while(true) {
            /// is, is not

            if("as"==t.value) {
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
                    parent.getModule.dumpToConsole();
                    throw new CompilerError(Err.BAD_RHS_EXPR, t, "Bad RHS");
            }
        }
    }
    Expression attachAndRead(TokenNavigator t, ASTNode parent, Expression newExpr) {
        ASTNode prev = parent;
        if(prev.isA!Expression) {
            /// Ensure two binary expressions in a row do not have the same priority
            /// as this could lead to ambiguous results
            if(newExpr.isBinary && parent.isBinary) {
                if(newExpr.priority == parent.as!Binary.priority) {
                    errorAmbiguousExpr(parent);
                }
            }

            /// Adjust to account for operator precedence
            Expression prevExpr = cast(Expression)prev;
            while(prevExpr.parent && newExpr.priority >= prevExpr.priority) {
                if(prevExpr.parent.isA!Expression) {
                    prevExpr = prevExpr.parent.as!Expression;
                    prev = prevExpr;
                } else {
                    prev = prevExpr.parent;
                    break;
                }
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

        t.skip(TT.LBRACKET);

        while(t.type!=TT.RBRACKET) {

            if(t.peek(1).type==TT.EQUALS) {
                /// paramname = expr
                assert(false, "call paramname = expr");
            } else {
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

            auto args = makeNode!Arguments(t);
            f.addToEnd(args);

            auto type = makeNode!FunctionType(t);
            type.args = args;
            f.type = type;

            t.skip(TT.LCURLY);

            int arrow = t.findInScope(TT.RT_ARROW);
            if(arrow!=-1) {
                /// collect the args
                while(t.type!=TT.RT_ARROW) {

                    varParser().parse(t, args);

                    t.expect(TT.RT_ARROW, TT.COMMA);
                    if(t.type==TT.COMMA) t.next;
                }
                t.skip(TT.RT_ARROW);
            } else {
                /// no args
            }

            // statements
            while(t.type != TT.RCURLY) {
                stmtParser().parse(t, f);
            }
            t.skip(TT.RCURLY);

            module_.addLiteralFunction(f);
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
        parent.addToEnd(var);

        /// Call string.new(this, byte*, int)

        Call call    = b.call("new", null);
        auto thisPtr = b.addressOf(b.identifier(var.name));
        call.addToEnd(thisPtr);
        call.addToEnd(s);
        call.addToEnd(LiteralNumber.makeConst(s.calculateLength(), TYPE_INT));

        auto dot = b.dot(b.identifier(var.name), call);

        auto v = b.valueOf(dot);
        parent.addToEnd(v);
    }
    ///
    /// constructor ::= identifier "(" { cexpr [ "," cexpr ] } ")"
    /// cexpr :: expression | paramname "=" expression
    ///
    void parseStructConstructor(TokenNavigator t, ASTNode parent) {

        /// type
        auto type = typeParser().parse(t, parent);
        if(!type) {
            errorMissingType(t, t.value);
        }
        if(!type.isDefine && !type.isNamedStruct) {
            errorBadSyntax(t, "Expecting a struct name here");
        }

        /// Prepare the call to new(this, ...)
        auto b = module_.builder(parent);
        Call call = b.call("new", null);

        string name    = type.isDefine ? type.getDefine.name : type.getNamedStruct.name;
        string varName = module_.makeTemporary(name);

        Expression thisPtr;
        /// allocate memory
        if(type.isPtr) {
            /// Heap malloc
            assert(false, "Implement malloc constructor");
            // todo - set thisPtr
        } else {
            /// Stack alloca
            auto var = b.variable(varName, type, false);
            parent.addToEnd(var);

            thisPtr = b.addressOf(b.identifier(var.name));
        }

        call.addToEnd(thisPtr);

        Expression dot = b.dot(b.identifier(varName), call);
        if(type.isValue) {
            dot = b.valueOf(dot);
        }
        parent.addToEnd(dot);

        /// (
        t.skip(TT.LBRACKET);

        while(t.type!=TT.RBRACKET) {

            if(t.peek(1).type==TT.EQUALS) {
                /// paramname = expr
                assert(false, "constructor paramname = expr");
            } else {
                parse(t, call);
            }

            t.expect(TT.COMMA, TT.RBRACKET);
            if(t.type==TT.COMMA) t.next;
        }
        /// )
        t.skip(TT.RBRACKET);
    }
    ///
    /// #length etc...
    ///
    void parseMetaFunction(TokenNavigator t, ASTNode parent) {
        /// #
        t.skip(TT.HASH);

        Expression e;

        /// name
        if(t.value=="ptr") {
            e = makeNode!AddressOf(t);
        } else if(t.value=="val") {
            e = makeNode!ValueOf(t);
        } else {
            e = makeNode!MetaFunction(t);
            e.as!MetaFunction.name = t.value;
        }
        parent.addToEnd(e);
        t.next;

        /// (
        t.skip(TT.LBRACKET);

        /// expr
        parse(t, e);

        /// )
        t.skip(TT.RBRACKET);
    }
    void parseAssert(TokenNavigator t, ASTNode parent) {
        auto a = makeNode!Assert(t);
        parent.addToEnd(a);

        t.skip("assert");

        parse(t, a);
    }
}

