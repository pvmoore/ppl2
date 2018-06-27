module ppl2.ast.expression;

import ppl2.internal;

abstract class Expression : Statement {

    abstract int priority() const;

    bool isConst() { return false; }

    bool isStartOfChain() const {
        //logln("isStartOfChain %s %s", this, previousSibling);
        if(parent.isDot) {
            if(children.length==0) {
                return prevSibling() is null;
            } else if(children[0].isDot) {
                return prevSibling() is null;
            }
            return false;
        }
        return true;
    }
    Expression prevLink() {
        if(!parent.isDot) return null;
        if(isStartOfChain()) return null;

        ASTNode prev = prevSibling();
        if(prev) {
            if(prev.isDot) {
                return cast(Expression)prev.children[1];
            } else {
                return cast(Expression)prev;
            }
        }
        return null;
    }
}