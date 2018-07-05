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

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    int fold() {
        watch.start();

        nodesFolded = 0;
        foreach(r; module_.activeRoots.values.dup) {
            recursiveVisit(r);
        }

        watch.stop();
        return nodesFolded;
    }
    //===========================================================================================
    void visit(AddressOf n) {

    }
    void visit(As n) {
        if(!n.isResolved) return;

        auto lit = n.left().as!LiteralNumber;
        if(lit && n.rightType.isValue) {

            lit.value.as(n.rightType);
            lit.type = n.rightType;
            lit.str  = lit.value.getString();

            n.parent.replaceChild(n, lit);
            nodesFolded++;
            return;
        }
    }
    void visit(Assert n) {
        if(!n.expr().isResolved) return;

        auto lit = n.expr().as!LiteralNumber;
        if(lit) {
            if(lit.value.getBool()==false) {
                throw new CompilerError(Err.ASSERT_FAILED, n, "Assertion failed");
            }

            nodesFolded++;
            n.parent.replaceChild(n, lit);
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

            lit.str  = lit.value.getString();
            lit.type = n.type;

            nodesFolded++;
            n.parent.replaceChild(n, lit);
            return;
        }
    }
    void visit(Identifier n) {
        auto type = n.target.getType;
        auto var  = n.target.getVariable;

        if(type.isValue && (type.isInteger || type.isReal || type.isBool)) {
            assert(var.hasInitialiser);

            Initialiser ini = var.initialiser();
            auto lit        = ini.literal();

            if(lit && lit.isResolved) {
                n.parent.replaceChild(n, lit.copy());
                nodesFolded++;
                n.target.dereference();
                return;
            }
        }
    }
    void visit(Initialiser n) {

    }
    void visit(LiteralNumber n) {

    }
    void visit(LiteralNull n) {

    }
    void visit(MetaFunction n) {
        n.rewrite();
        nodesFolded++;
    }
    void visit(Parenthesis n) {
        if(n.expr().isA!Parenthesis) {
            /// Remove unnecessary parens ((expr))
            n.parent.replaceChild(n, n.expr());
            nodesFolded++;
            return;
        }
        auto lit = n.expr().as!LiteralNumber;
        if(lit) {
            n.parent.replaceChild(n, lit);
            nodesFolded++;
            return;
        }
    }
    void visit(TypeExpr n) {

    }
    void visit(Unary n) {
        if(!n.isResolved) return;

        auto lit = n.expr().as!LiteralNumber;
        if(lit) {
            lit.value.applyUnary(n.op);
            lit.str = lit.value.getString();

            nodesFolded++;
            n.parent.replaceChild(n, lit);
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

            if(fold) {
                //dd("fold", typeid(m), m.nid);
                m.visit!ModuleConstantFolder(this);
            }

            foreach(n; m.children) {
                recursiveVisit(n);
            }
        }
    }
}