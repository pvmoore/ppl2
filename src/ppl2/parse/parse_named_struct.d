module ppl2.parse.parse_named_struct;

import ppl2.internal;

final class NamedStructParser {
private:
    Module module_;

    auto stmtParser()   { return module_.stmtParser; }
    auto typeDetector() { return module_.typeDetector; }
    auto typeFinder()   { return module_.typeFinder; }
    auto builder()      { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    ///
    /// "struct" name "=" [ <> ] AnonStruct
    ///
    void parse(Tokens t, ASTNode parent) {

        /// struct
        t.skip("struct");

        NamedStruct n = makeNode!NamedStruct(t);
        parent.add(n);

        n.moduleName = module_.canonicalName;
        n.access     = t.access();

        /// Is this type already defined?
        auto type = typeFinder.findType(t.value, parent);

        //dd("parseNamedStruct", t.value);
        if(type) {
            //dd("redefinition", type);
            if(type.isAlias) {
                if(type.getAlias.isTemplateProxy) {
                    /// Allow template proxy as this is what we are replacing
                } else {
                    throw new CompilerError(n,
                        "Type %s already defined".format(t.value));
                }
            } else if(type.isNamedStruct) {
                auto ns = type.getNamedStruct;

                if(ns.isDeclarationOnly) {
                    /// Re-use previous definition
                    ns.isDeclarationOnly = false;

                    n.detach();

                    n = ns;
                    log("Re-using redefined struct %s", n.name);

                } else {
                    throw new CompilerError(n,
                        "Struct %s already defined".format(t.value));
                }
            }
        }

        /// name
        n.name = t.value;
        t.next;

        ///
        /// Stop here if this is just a declaration
        ///
        if(t.type!=TT.LANGLE && t.type!=TT.LCURLY) {
            n.isDeclarationOnly = true;
            return;
        }

        bool isModuleScope = parent.isModule ||
                            (parent.isComposite && parent.as!Composite.parent.isModule);
        if(isModuleScope) {
            t.startAccessScope();
        }

        if(t.type==TT.LANGLE) {
            /// This is a template

            t.skip(TT.LANGLE);

            n.blueprint = new TemplateBlueprint;

            /// template params < A,B,C >
            while(t.type!=TT.RANGLE) {

                if(typeDetector().isType(t, n)) {
                    throw new CompilerError(t,
                        "Template param name cannot be a type");
                }

                n.blueprint.paramNames ~= t.value;
                t.next;

                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            /// {
            t.expect(TT.LCURLY);

            int start = t.index;
            int end   = t.findEndOfBlock(TT.LCURLY);
            n.blueprint.setStructTokens(null, t[start..start+end+1].dup);
            t.next(end+1);

            //dd("Struct template decl", n.name, n.blueprint.paramNames, n.blueprint.tokens.toString);

        } else {
            /// This is a concrete struct

            n.type = parseBody(t, n);

            /// Do some house-keeping
            auto anonStruct = n.type;

            addDefaultConstructor(t, n, anonStruct);
            addImplicitReturnThis(n);
            addCallToDefaultConstructor(n);
            moveInitCodeInsideDefaultConstructor(n, anonStruct);
        }

        if(isModuleScope) {
            t.endAccessScope();
        }
    }
    AnonStruct parseBody(Tokens t, ASTNode node) {
        /// {
        auto s = makeNode!AnonStruct(t);
        node.add(s);

        t.skip(TT.LCURLY);

        /// Statements
        while(t.type!=TT.RCURLY) {

            stmtParser().parse(t, s);

            if(t.type==TT.COMMA) t.next;
        }
        /// }
        t.skip(TT.RCURLY);
        return s;
    }
    /// If there is no default constructor 'new()' then create one
    void addDefaultConstructor(Tokens t, NamedStruct ns, AnonStruct anonStruct) {
        auto defCons = ns.getDefaultConstructor();
        if(!defCons) {

            defCons            = makeNode!Function(t);
            defCons.name       = "new";
            defCons.moduleName = module_.canonicalName;
            anonStruct.add(defCons);

            auto params = makeNode!Parameters(t);
            params.addThisParameter(ns);

            auto type   = makeNode!FunctionType(t);
            type.params = params;

            auto bdy  = makeNode!LiteralFunction(t);
            bdy.add(params);
            bdy.type = type;
            defCons.add(bdy);
        }
    }
    /// Add implicit return 'this' at the end of all constructors
    void addImplicitReturnThis(NamedStruct ns) {
        auto allCons = ns.getConstructors();
        foreach(c; allCons) {
            auto bdy = c.getBody();
            assert(bdy);

            /// Don't allow user to add their own return
            if(bdy.getReturns().length > 0) {
                throw new CompilerError(bdy.getReturns()[0], "Constructor should not include a return statement");
            }

            auto ret = builder().return_(builder().identifier("this"));
            bdy.add(ret);
        }
    }
    /// Every non-default constructor should start with a call to the default constructor
    void addCallToDefaultConstructor(NamedStruct ns) {
        auto allCons = ns.getConstructors();
        foreach(c; allCons) {
            if(!c.isDefaultConstructor) {
                auto bdy = c.getBody();
                assert(bdy);
                assert(bdy.first().isA!Parameters);

                auto call = builder().call("new", null);
                auto arg  = builder().identifier("this");

                call.add(arg);
                /// Add it after Arguments
                bdy.insertAt(1, call);
            }
        }
    }
    /// Move struct member variable initialisers into the default constructor
    void moveInitCodeInsideDefaultConstructor(NamedStruct ns, AnonStruct anonStruct) {
        auto initFunc = ns.getDefaultConstructor();
        assert(initFunc);

        foreach_reverse(v; anonStruct.getMemberVariables()) {
            if(v.hasInitialiser) {
                /// Arguments should always be at index 0 so add these at index 1
                initFunc.getBody().insertAt(1, v.initialiser);
            }
        }
    }
}