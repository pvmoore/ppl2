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

    bool isType(TokenNavigator t, ASTNode parent) {
        //dd("isType");
        bool res;
        Type type;
        int numChildren = parent.numChildren();
        try{
            t.markPosition();
            type = parse(t, parent);
            res = type !is null;
        }catch(TypeParserBailout e) {
            res = false;
        }catch(CompilerError e) {
            throw e;
        }finally{
            t.resetToMark();
            /// Ensure we remove any nodes that were added
            while(parent.numChildren > numChildren) parent.removeLast();
        }
       // dd("isType end", res);
        return res;
    }
    ///
    /// Parse type. On success the type is returned and the the token pos adjusted.
    /// If a type is not found then the token pos is reset and null is returned.
    ///
    Type tryParse(TokenNavigator t, ASTNode parent) {
        //dd("tryParse");
        Type type;
        int numChildren = parent.numChildren();
        try{
            t.markPosition();
            type = parse(t, parent);
            t.discardMark();
        }catch(CompilerError e) {
            throw e;
        }catch(TypeParserBailout e) {
            t.resetToMark();
            /// Ensure we remove any nodes that were added
            while(parent.numChildren > numChildren) parent.removeLast();
        }
        //dd("tryParse end", type);
        return type;
    }
    Type parse(TokenNavigator t, ASTNode node) {
        //dd("parseType");
        string value = t.value;
        Type type    = null;

        if(t.type==TT.LSQBRACKET && t.peek(1).type==TT.COLON) {
            /// array "[:" type count_expr "]"
            type = parseArrayType(t, node);
        } else if(t.type==TT.LSQBRACKET || t.type==TT.LANGLE) {
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
            /// Is it a NamedStruct?
            if(type is null) {
                auto ns = findType!NamedStruct(value, node);
                if(ns) {
                    t.next;
                    type = ns;
                }
            }
            /// is it a Define?
            if(type is null) {
                auto def = findType!Define(value, node);
                if(def) {
                    t.next;
                    type = def.isKnown ? def.type : def;
                }
            }
            // todo - template type
            if(type is null) {

            }
        }
        // todo - template init < ... >

        /// ptr depth
        if(type !is null) {
            int pd = 0;
            while(t.type==TT.ASTERISK) {
                t.next;
                pd++;
            }
            type = PtrType.of(type, pd);
        }

        //dd("parseType end", type);
        return type;
    }
    ///
    /// struct_type   ::= [ template_args ] "[" statement { statement } "]"
    /// template_args ::= "<" name { "," name } ">"
    ///
    Type parseAnonStruct(TokenNavigator t, ASTNode node) {

        if(t.type==TT.LANGLE) {
            /// template struct
            assert(node.isA!NamedStruct);
            auto ns = node.as!NamedStruct;

            /// < .. >
            t.skip(TT.LANGLE);
            while(t.type!=TT.RANGLE) {
                ns.templateArgNames ~= t.value;
                t.next;
                t.expect(TT.RANGLE, TT.COMMA);
                if (t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            /// [
            t.expect(TT.LSQBRACKET);

            int start = t.index;
            int end   = t.findEndOfBlock(TT.LSQBRACKET);
            ns.tokens = t.get(start, start+end).dup;
            t.next(end+1);
            return makeNode!AnonStruct(t);
        }
        /// Struct

        /// [
        auto s = makeNode!AnonStruct(t);
        node.addToEnd(s);

        t.skip(TT.LSQBRACKET);

        /// Statements
        while(t.type!=TT.RSQBRACKET) {
            stmtParser().parse(t, s);

            /// If this is an expression then bail out
            if(s.hasChildren && s.last.isExpression) throw new TypeParserBailout();

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
            errorMissingType(t, "Type %s not found".format(t.value));
        }

        if(t.type!=TT.RSQBRACKET) {
            /// count

            if(t.type==TT.QMARK) {
                /// get the count from the initialiser
                a.inferCount = true;
                t.next;
            } else {
                exprParser().parse(t, a);
            }
        }

        t.skip(TT.RSQBRACKET);

        return a;
    }
    ///
    /// "{" [ type { "," type } ] "->" [ type ] "}"
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