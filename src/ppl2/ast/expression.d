module ppl2.ast.expression;

import ppl2.internal;

abstract class Expression : Statement {

    abstract int priority() const;

    bool isConst() { return false; }

    bool isStartOfChain() {
        if(!parent.isDot) return true;
        if(index()!=0) return false;

        return parent.as!Dot.isStartOfChain();
    }
    ///
    /// Get the previous link in the chain. Assumes there is one.
    ///
    Expression prevLink() {
        if(!parent.isDot) return null;
        if(isStartOfChain()) return null;

        auto prev = prevSibling();
        if(prev) {
            return prev.as!Expression;
        }
        assert(parent.parent.isDot);
        return parent.parent.as!Dot.left();
    }
}