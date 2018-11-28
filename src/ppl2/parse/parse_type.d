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
    Type parseForTemplate(Tokens t, ASTNode node) {
        return parse(t, node, false);
    }
    Type parse(Tokens t, ASTNode node, bool addToNode = true) {
        //dd("parseType", node.id, t.get);
        string value = t.value;
        Type type    = null;

        if(t.type==TT.LCURLY) {
            /// {int a,bool->int}
            type = parseFunctionType(t, node, addToNode);
        } else if(t.type==TT.LSQBRACKET) {
            /// "[" types "]"
            type = parseAnonStruct(t, node, addToNode);
        } else if(t.value=="#typeof") {
            type = parseTypeof(t, node, addToNode);
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
            /// Is it a NamedStruct, Enum or Alias?
            if(type is null) {
                type = parseAliasOrEnumOrNamedStruct(t, node);
            }
        }

        if(t.type==TT.LANGLE) {
            errorBadSyntax(module_, t, "Cannot parameterise this type");
        }

        if(type !is null) {

            if(t.type==TT.DBL_COLON) {
                /// Inner type eg.
                /// type:: type2 ::
                ///        ^^^^^^^^ repeat
                /// So far we have type

                /// type2 must be one of: ( Enum | NamedStruct | NamedStruct<...> )

                //auto alias_        = makeNode!Alias(t);
                //alias_.moduleName  = module_.canonicalName;
                //alias_.isInnerType = true;
                //alias_.type = type;
                //type = alias_;
                //
                //if(addToNode) {
                //    node.add(alias_);
                //}

                Alias alias_;

                while(t.type==TT.DBL_COLON) {
                    /// ::
                    t.skip(TT.DBL_COLON);

                    if(t.type!=TT.IDENTIFIER) {
                        errorBadSyntax(module_, t, "Expecting a type name");
                    }

                    /// ( Enum | NamedStruct | NamedStruct<...> )
                    auto a        = makeNode!Alias(t);
                    a.isInnerType = true;
                    a.name        = t.value;
                    a.moduleName  = module_.canonicalName;
                    t.next;

                    if(!alias_) {
                        a.type = type;
                    } else {
                        a.type = alias_;
                    }

                    /// optional <...>
                    a.templateParams = collectTemplateParams(t, node);

                    //dd("a:", a);

                    alias_ = a;
                }
                if(addToNode) {
                    node.add(alias_);
                }
                type = alias_;

                //dd("alias_:", alias_);
            }

            /// ptr depth
            while(true) {
                int pd = 0;
                while(t.type==TT.ASTERISK) {
                    t.next;
                    pd++;
                }
                type = PtrType.of(type, pd);


                if(t.onSameLine && t.type==TT.LSQBRACKET) {
                    type = parseArrayType(t, type, node, addToNode);

                } else break;
            }
        }

        return type;
    }
private:
    Type parseAliasOrEnumOrNamedStruct(Tokens t, ASTNode node) {

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

        auto imp = findImportByAlias(t.value, node);
        if(!imp) return null;

        //if(t.peek(1).type==TT.DBL_COLON) warn(t, "Deprecated module alias ::");

        if(t.peek(1).type!=TT.DOT) return null;

        t.next(2);

        /// Assuming for now that inner structs don't exist,
        /// these are the only valid types:

        /// imp.  alias
        /// imp.  alias<>

        string name = t.value;
        t.next;

        Type type = imp.getAlias(name);
        if(!type) errorMissingType(module_, t, t.value);

        Type[] templateParams = collectTemplateParams(t, node);
        if(templateParams.length>0) {
            type = typeFinder.findTemplateType(type, node, templateParams);
        } else {
            auto alias_ = type.as!Alias;
            module_.buildState.aliasEnumOrStructRequired(alias_.moduleName, alias_.name);
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

            varParser().parseAnonStructMember(t, s);

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
    /// int[expr] array
    /// int[expr][expr][expr] array // any number of sub arrays allowed
    Type parseArrayType(Tokens t, Type subtype, ASTNode node, bool addToNode) {
        if(!addToNode && subtype.isA!ASTNode) {
            subtype.as!ASTNode.detach();
        }

        auto a = makeNode!ArrayType(t);
        node.add(a);

        /// [
        t.skip(TT.LSQBRACKET);

        a.subtype = subtype;

        /// count
        if(t.type!=TT.RSQBRACKET) {
            exprParser().parse(t, a);
        }

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

            varParser().parseFunctionTypeParameter(t, f);

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
            varParser().parseReturnType(t, f);
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
    /// #typeof ( expr )
    Type parseTypeof(Tokens t, ASTNode node, bool addToNode) {
        /// #typeof
        t.next;

        /// (
        t.skip(TT.LBRACKET);

        auto a = makeNode!Alias(t);
        a.isTypeof = true;
        node.add(a);

        exprParser().parse(t, a);

        /// )
        t.skip(TT.RBRACKET);

        if(!addToNode) {
            a.detach();
        }
        return a;
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