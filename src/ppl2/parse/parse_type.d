module ppl2.parse.parse_type;

import ppl2.internal;

final class TypeParser {
private:
    Module module_;

    auto moduleParser() { return module_.parser; }
    auto exprParser()   { return module_.exprParser; }
    auto stmtParser()   { return module_.stmtParser; }
    auto varParser()    { return module_.varParser; }
    auto typeFinder()   { return module_.typeFinder; }
    auto typeDetector() { return module_.typeDetector; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    Type parse(Tokens t, ASTNode node, bool addToNode = true) {
        //dd("parseType", node.id, t.get);
        string value = t.value;
        Type type    = null;

        if(t.type==TT.LCURLY) {
            /// {int a,bool->int}
            type = parseFunctionType(t, node, addToNode);
        } else if(t.type==TT.LSQBRACKET) {
            int end = typeDetector().endOffset(t, node, 1);
            if(end!=-1 && t.peek(end+1).type==TT.COLON) {
                /// "[" type ":" count_expr "]"
                type = parseArrayStruct(t, node, addToNode);
            } else {
                /// "[" types "]"
                type = parseAnonStruct(t, node, addToNode);
            }
        } else {
            /// built-in type
            int p = g_builtinTypes.get(value, -1);
            if(p!=-1) {
                t.next;
                type = new BasicType(p);
            }
            if(type is null) {
                type = t.get.templateType;
                if(type) t.next;
            }
            if(type is null) {
                type = parseImportAlias(t, node);
            }
            /// Is it a NamedStruct or Alias?
            if(type is null) {
                type = parseAliasOrNamedStruct(t, node);
            }
        }

        if(t.type==TT.LANGLE) {
            errorBadSyntax(module_, t, "Cannot parameterise this type");
        }

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
private:
    Type parseAliasOrNamedStruct(Tokens t, ASTNode node) {

        /// Get the name
        string name = t.value;
        t.markPosition();
        t.next;

        Type[] templateParams = collectTemplateParams(t, node);

        auto type = typeFinder.findType(name, node);
        if(type && templateParams.length>0) {
            type = typeFinder.findTemplateType(type, node, templateParams);
        }

        if(!type) {
            t.resetToMark();
        }
        return type;
    }
    Type parseImportAlias(Tokens t, ASTNode node) {

        auto imp = findImportByAlias(t.value ,node);
        if(!imp) return null;
        if(t.peek(1).type!=TT.DBL_COLON) return null;

        t.next(2);

        /// Assuming for now that inner structs don't exist,
        /// these are the only valid types:

        /// imp::  alias
        /// imp::  alias<>

        string name = t.value;
        t.next;

        Type type = imp.getAlias(name);
        if(!type) errorMissingType(module_, t, t.value);

        Type[] templateParams = collectTemplateParams(t, node);
        if(templateParams.length>0) {
            type = typeFinder.findTemplateType(type, node, templateParams);
        } else {
            auto alias_ = type.as!Alias;
            module_.buildState.aliasOrStructRequired(alias_.moduleName, alias_.name);
        }

        return type;
    }
    ///
    /// anon_struct ::= "[" statement { statement } "]"
    ///
    Type parseAnonStruct(Tokens t, ASTNode node, bool addToNode) {

        /// [
        auto s = makeNode!AnonStruct(t);
        node.add(s);

        t.skip(TT.LSQBRACKET);

        /// Statements
        while(t.type!=TT.RSQBRACKET) {

            stmtParser().parse(t, s);

            if(t.type==TT.COMMA) t.next;
        }
        /// ]
        t.skip(TT.RSQBRACKET);

        if(!addToNode) {
            s.detach();
        }
        return s;
    }
    ///
    /// array_type ::= "[" type ":" count_expr "]"
    ///
    Type parseArrayStruct(Tokens t, ASTNode node, bool addToNode) {
        auto a = makeNode!ArrayType(t);
        node.add(a);

        /// [
        t.skip(TT.LSQBRACKET);

        a.subtype = parse(t, a);
        assert(a.subtype);

        if(a.subtype is null) {
            errorMissingType(module_, t, t.value);
        }

        /// :
        t.skip(TT.COLON);

        /// count
        exprParser().parse(t, a);

        /// ]
        t.skip(TT.RSQBRACKET);

        if(!addToNode) {
            a.detach();
        }
        return a;
    }
    ///
    /// function_type ::= "{" [ type { "," type } ] "->" [ type ] "}"
    ///
    Type parseFunctionType(Tokens t, ASTNode node, bool addToNode) {
        //dd("function type");

        t.skip(TT.LCURLY);

        auto f = makeNode!FunctionType(t);
        node.add(f);

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
            f.add(v);
        }

        t.skip(TT.RCURLY);

        if(!addToNode) {
            f.detach();
        }

        return PtrType.of(f, 1);
    }
    Type[] collectTemplateParams(Tokens t, ASTNode node) {
        if(t.type!=TT.LANGLE) return null;

        Type[] templateParams;

        t.skip(TT.LANGLE);

        while(t.type!=TT.RANGLE) {

            t.markPosition();

            auto tt = parse(t, node);
            if(!tt) {
                t.resetToMark();
                errorMissingType(module_, t);
            }
            t.discardMark();

            templateParams ~= tt;

            t.expect(TT.COMMA, TT.RANGLE);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RANGLE);

        return templateParams;
    }
}