module ppl2.ast.stmt_import;

import ppl2.internal;

final class Import : Statement {
    string moduleName;
    Module mod;

/// ASTNode
    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.IMPORT; }
///
    override string toString() {
        return "Import %s".format(moduleName);
    }
}