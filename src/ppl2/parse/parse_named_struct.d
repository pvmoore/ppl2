module ppl2.parse.parse_named_struct;

import ppl2.internal;

final class NamedStructParser {
private:
    Module module_;

    TypeParser typeParser()     { return module_.typeParser; }
    TypeDetector typeDetector() { return module_.typeDetector; }
    NodeBuilder builder()       { return module_.nodeBuilder; }
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
        parent.addToEnd(n);

        n.moduleName = module_.canonicalName;
        n.access     = t.access();

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

        bool isModuleScope = parent.isModule ||
                            (parent.isComposite && parent.as!Composite.parent.isModule);
        if(isModuleScope) {
            t.startAccessScope();
        }

        /// =
        t.skip(TT.EQUALS);

        if(t.type==TT.LANGLE) {
            /// This is a template

            t.skip(TT.LANGLE);

            n.blueprint = new TemplateBlueprint;

            /// template params < A,B,C >
            while(t.type!=TT.RANGLE) {

                if(typeDetector().isType(t, n)) {
                    throw new CompilerError(Err.TEMPLATE_PARAM_NAME_IS_TYPE, t,
                        "Template param name cannot be a type");
                }

                n.blueprint.paramNames ~= t.value;
                t.next;

                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            /// [
            t.expect(TT.LSQBRACKET);

            int start = t.index;
            int end   = t.findEndOfBlock(TT.LSQBRACKET);
            n.blueprint.setTokens(null, t.get(start, start+end).dup);
            t.next(end+1);

            dd("Struct template decl", n.name, n.blueprint.paramNames, n.blueprint.tokens.toString);

        } else {
            /// This is a concrete struct

            /// anon struct
            n.type = typeParser.parse(t, n).as!AnonStruct;

            /// Do some house-keeping
            auto anonStruct = n.type;

            addDefaultConstructor(t, n, anonStruct);
            addImplicitReturnThis(anonStruct);
            addCallToDefaultConstructor(anonStruct);
            moveInitCodeInsideDefaultConstructor(anonStruct);

        }

        if(isModuleScope) {
            t.endAccessScope();
        }
    }
private:
    /// If there is no default constructor 'new()' then create one
    void addDefaultConstructor(Tokens t, NamedStruct ns, AnonStruct anonStruct) {
        auto defCons = anonStruct.getDefaultConstructor();
        if(!defCons) {

            defCons            = makeNode!Function(t);
            defCons.name       = "new";
            defCons.moduleName = module_.canonicalName;
            anonStruct.addToEnd(defCons);

            auto params = makeNode!Parameters(t);
            params.addThisParameter(ns);

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