module ppl2.parse.parse_named_struct;

import ppl2.internal;

final class NamedStructParser {
private:
    Module module_;

    TypeParser typeParser() { return module_.typeParser; }
    NodeBuilder builder() { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    ///
    /// "struct" name "=" [ <> ] AnonStruct
    ///
    void parse(TokenNavigator t, ASTNode parent) {

        /// struct
        t.skip("struct");

        NamedStruct n = makeNode!NamedStruct(t);
        parent.addToEnd(n);

        n.moduleName = module_.canonicalName;

        /// Is this type already defined?
        auto type = findType(t.value, parent);

        //dd("parseNamedStruct", t.value);
        if(type) {
            dd("redefinition", type);
            if(type.isDefine) {
                if(type.getDefine.isTemplateProxy) {
                    /// Allow template proxy as this is what we are replacing
                } else {
                    throw new CompilerError(Err.DUPLICATE_DEFINITION, n,
                        "Type %s already defined".format(t.value));
                }
            } else if(type.isNamedStruct) {
                auto ns = type.getNamedStruct;
                if(ns.type.numMemberVariables==0) {
                    /// Re-use previous definition
                    n.detach();

                    ns.removeAt(0);
                    n = ns;
                    log("Re-using redefined struct %s", n.name);

                } else {
                    throw new CompilerError(Err.DUPLICATE_DEFINITION, n,
                        "Struct %s already defined".format(t.value));
                }
            }
        }

        /// name
        n.name = t.value;
        t.next;

        t.push(n);

        /// =
        t.skip(TT.EQUALS);

        if(t.type==TT.LANGLE) {
            /// This is a template

            t.skip(TT.LANGLE);

            /// template params < A,B,C >
            while(t.type!=TT.RANGLE) {
                n.templateParamNames ~= t.value;
                t.next;

                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            /// [
            t.expect(TT.LSQBRACKET);

            int start = t.index;
            int end   = t.findEndOfBlock(TT.LSQBRACKET);
            n.tokens = t.get(start, start+end).dup;
            t.next(end+1);

            dd("Struct template decl", n.name, n.templateParamNames, n.tokens.toString);

        } else {
            /// This is a concrete struct

            /// anon struct
            n.type = typeParser.parse(t, n).as!AnonStruct;

            /// Do some house-keeping
            auto anonStruct = n.type;

            addDefaultConstructor(t, anonStruct);
            addImplicitThisParam(n, anonStruct);
            addImplicitReturnThis(anonStruct);
            addCallToDefaultConstructor(anonStruct);
            moveInitCodeInsideDefaultConstructor(anonStruct);

        }

        t.popNamedStruct();
    }
private:
    /// If there is no default constructor 'new()' then create one
    void addDefaultConstructor(TokenNavigator t, AnonStruct anonStruct) {
        auto defCons = anonStruct.getDefaultConstructor();
        if(!defCons) {

            defCons            = makeNode!Function(t);
            defCons.name       = "new";
            defCons.moduleName = module_.canonicalName;
            anonStruct.addToEnd(defCons);

            auto params = makeNode!Parameters(t);
            auto type   = makeNode!FunctionType(t);
            type.params = params;

            auto bdy  = makeNode!LiteralFunction(t);
            bdy.addToEnd(params);
            bdy.type = type;
            defCons.addToEnd(bdy);
        }
    }
    /// Add implicit return 'this' at the end of all constructors
    void addImplicitReturnThis(AnonStruct anonStruct) {
        auto allCons = anonStruct.getConstructors();
        foreach(c; allCons) {
            auto bdy = c.getBody();
            assert(bdy);

            /// Don't allow user to add their own return
            if(bdy.getReturns().length > 0) {
                errorIncorrectReturnType(bdy.getReturns()[0],
                    "Constructor should not include a return statement");
            }

            auto ret = builder().return_(builder().identifier("this"));
            bdy.addToEnd(ret);
        }
    }
    /// Add the implicit this* to all member functions including constructors (at root level only)
    void addImplicitThisParam(NamedStruct ns, AnonStruct anonStruct) {
        foreach(f; anonStruct.getMemberFunctions()) {
            assert(!f.isExtern && !f.isImport);
            if(f.isTemplate) {
                // todo -  should we add it here or later?
            } else {
                f.params().addThisParameter(ns);
            }
        }
    }
    /// Every non-default constructor should start with a call to the default constructor
    void addCallToDefaultConstructor(AnonStruct anonStruct) {
        auto allCons = anonStruct.getConstructors();
        foreach(c; allCons) {
            if(!c.isDefaultConstructor) {
                auto bdy = c.getBody();
                assert(bdy);
                assert(bdy.first().isA!Parameters);

                auto call = builder().call("new", null);
                auto arg  = builder().identifier("this");

                call.addToEnd(arg);
                /// Add it after Arguments
                bdy.insertAt(1, call);
            }
        }
    }
    /// Move struct variable initialisers into the default constructor
    void moveInitCodeInsideDefaultConstructor(AnonStruct anonStruct) {
        auto initFunc = anonStruct.getDefaultConstructor();
        assert(initFunc);

        foreach_reverse(v; anonStruct.getMemberVariables()) {
            if(v.hasInitialiser) {
                /// Arguments should always be at index 0 so add these at index 1
                initFunc.getBody().insertAt(1, v.initialiser);
            }
        }
    }
}