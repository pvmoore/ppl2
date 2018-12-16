module ppl2.parse.parse_function;

import ppl2.internal;

final class FunctionParser {
private:
    Module module_;

    auto exprParser()   { return module_.exprParser; }
    auto typeDetector() { return module_.typeDetector; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    ///
    /// function::= [ "static" ] identifier [ template params] expr_function_literal
    ///
    void parse(Tokens t, ASTNode parent) {

        auto f = makeNode!Function(t);
        parent.add(f);

        auto ns = f.getAncestor!Struct;

        if(t.value=="static") {
            f.isStatic = true;
            t.next;
        }

        /// name
        f.name       = t.value;
        f.moduleName = module_.canonicalName;
        t.next;

        if(f.isStatic && f.name=="new") {
            module_.addError(t, "Struct constructors cannot be static", true);
        }
        if(f.name.startsWith("__") && !module_.canonicalName.startsWith("core::")) {
            module_.addError(t, "Function names starting with __ are reserved", true);
        }

        if(f.name=="operator" && ns) {
            /// Operator overload

            f.op = parseOperator(t);
            f.name ~= f.op.value;
            t.next;

            if(f.op==Operator.NOTHING) errorBadSyntax(module_, t, "Expecting an overloadable operator");
        }

        /// Function readonly access is effectively public
        f.access = t.access()==Access.PRIVATE ? Access.PRIVATE : Access.PUBLIC;

        /// =
        if(t.type==TT.EQUALS) {
            t.skip(TT.EQUALS);
            assert(false, "shouldn't get here");
        }

        /// Function template
        if(t.type==TT.LANGLE) {
            /// Template function - just gather the args and tokens
            t.skip(TT.LANGLE);

            f.blueprint = new TemplateBlueprint(module_);
            string[] paramNames;

            /// < .. >
            while(t.type!=TT.RANGLE) {

                if(typeDetector().isType(t, f)) {
                    module_.addError(t, "Template param name cannot be a type", true);
                }

                paramNames ~= t.value;
                t.next;
                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            /// {
            t.expect(TT.LCURLY);

            int start = t.index;
            int end   = t.findEndOfBlock(TT.LCURLY);
            f.blueprint.setFunctionTokens(ns, paramNames, t[start..start+end+1].dup);
            t.next(end+1);

            //dd("Function template decl", f.name, f.blueprint.paramNames, f.blueprint.tokens.toString);

        } else {

            /// function literal
            t.expect(TT.LCURLY);
            exprParser().parse(t, f);

            /// Add implicit this* parameter if this is a non-static struct member function
            if(ns && !f.isStatic) {
                f.params.addThisParameter(ns);
            }
        }
    }
}