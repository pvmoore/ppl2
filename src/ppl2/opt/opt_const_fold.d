module ppl2.opt.opt_const_fold;

import ppl2.internal;

final class ModuleConstantFolder {
private:
    Module module_;
    StopWatch watch;
    int nodesFolded;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    void clearState() {
        watch.reset();
    }

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    int fold() {
        watch.start();

        nodesFolded = 0;
        foreach(r; module_.getCopyOfActiveRoots()) {
            recursiveVisit(r);
            //if(module_.canonicalName=="test_template_functions") dd("   root", r);
        }

        watch.stop();
        return nodesFolded;
    }
    //===========================================================================================
    void visit(AddressOf n) {

    }
    void visit(As n) {
        if(!n.isResolved) return;

        /// If cast is unnecessary then just remove the As
        if(n.leftType.exactlyMatches(n.rightType)) {
            fold(n, n.left);
            return;
        }

        /// If left is a literal number then do the cast now
        auto lit = n.left().as!LiteralNumber;
        if(lit && n.rightType.isValue) {

            lit.value.as(n.rightType);
            lit.str = lit.value.getString();

            fold(n, lit);
            return;
        }
    }
    void visit(Assert n) {
        if(!n.expr().isResolved) return;

        auto lit = n.expr().as!LiteralNumber;
        if(lit) {
            if(lit.value.getBool()==false) {
                throw new CompilerError(n, "Assertion failed");
            }

            fold(n, lit);
        }
    }
    void visit(Binary n) {
        if(!n.isResolved) return;

        // todo - make this work
        if(n.op.isAssign) return;

        auto lft = n.left().as!LiteralNumber;
        auto rt  = n.right().as!LiteralNumber;
        if(lft && rt) {

            auto lit = lft.copy();

            lit.value.applyBinary(n.type, n.op, rt.value);
            lit.str = lit.value.getString();

            fold(n, lit);
            return;
        }
    }
    void visit(Composite n) {
        final switch(n.usage) with(Composite.Usage) {
            case STANDARD:
                /// Can be removed if empty
                /// Can be replaced if contains single child
                if(n.numChildren==0) {
                    n.detach();
                    nodesFolded++;
                } else if(n.numChildren==1) {
                    auto child = n.first();
                    fold(n, child);
                }
                break;
            case PERMANENT:
                /// Never remove or replace
                break;
            case PLACEHOLDER:
                /// Never remove
                /// Can be replaced if contains single child
                if(n.numChildren==1) {
                    auto child = n.first();
                    fold(n, child);
                }
                break;
        }
    }
    void visit(Identifier n) {
        if(!n.isResolved) return;

        auto type = n.target.getType;
        auto var  = n.target.getVariable;

        if(type.isValue && (type.isInteger || type.isReal || type.isBool)) {
            assert(var.hasInitialiser);

            Initialiser ini = var.initialiser();
            auto lit        = ini.literal();

            if(lit && lit.isResolved) {
                fold(n, lit.copy());
                n.target.dereference();
                return;
            }
        }
    }
    void visit(Initialiser n) {

    }
    void visit(Is n) {

    }
    void visit(LiteralNumber n) {

    }
    void visit(LiteralNull n) {

    }
    void visit(ModuleAlias n) {

    }
    void visit(Parenthesis n) {
        assert(n.numChildren==1);

        /// We don't need any Parentheses any more
        fold(n, n.expr());
    }
    void visit(TypeExpr n) {

    }
    void visit(Unary n) {
        if(!n.isResolved) return;

        auto lit = n.expr().as!LiteralNumber;
        if(lit) {
            lit.value.applyUnary(n.op);
            lit.str = lit.value.getString();

            fold(n, lit);
            return;
        }
    }
    void visit(ValueOf n) {

    }
private:
    bool isAttached(ASTNode n) {
        if(n.parent is null) return false;
        if(n.parent.isModule) return true;
        return isAttached(n.parent);
    }
    void recursiveVisit(ASTNode m) {
        if(isAttached(m)) {
            bool fold =
                //(it.isA!Variable && (it.as!Variable.isConst || it.as!Variable.numRefs==0)) ||
                (m.isExpression && m.as!Expression.isConst) //||
                //(it.isFunction && it.as!Function.numRefs==0)
            ;
            fold |= m.isComposite;

            if(fold) {
                //dd("fold", typeid(m), m.nid);
                m.visit!ModuleConstantFolder(this);
            }

            foreach(n; m.children) {
                recursiveVisit(n);
            }
        }
    }
    void fold(ASTNode replaceMe, ASTNode withMe) {
        auto p = replaceMe.parent;
        p.replaceChild(replaceMe, withMe);
        nodesFolded++;

        //if(module_.canonicalName=="test_statics") {
        //    dd("=======> folded", replaceMe.line, replaceMe, "child=", replaceMe.hasChildren ? replaceMe.first : null);
        //    dd("withMe=", withMe);
        //}
        /// Ensure active roots remain valid
        module_.addActiveRoot(withMe);
    }
}