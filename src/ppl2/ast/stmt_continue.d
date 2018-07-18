module ppl2.ast.stmt_continue;

import ppl2.internal;

final class Continue : Statement {
    Loop loop;

/// ASTNode
    override bool isResolved() { return loop !is null; }
    override NodeID id() const { return NodeID.CONTINUE; }
///

    override string toString() {
        return "Continue";
    }
}