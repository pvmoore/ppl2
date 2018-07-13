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
            /// Is it a NamedStruct or Define?
            if(type is null) {
                auto ty = findType(value, node);
                if(ty) {
                    t.next;
                    type = ty;
                    if(type.isA!Define && type.as!Define.isKnown) type = type.as!Define.type;
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