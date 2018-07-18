module ppl2.ast.stmt_break;

import ppl2.internal;

final class Break : Statement {
    Loop loop;

/// ASTNode
    override bool isResolved() { return loop !is null; }
    override NodeID id() const { return NodeID.BREAK; }
///

    override string toString() {
        return "Break";
    }
}