module ppl2.ast.stmt_import;

import ppl2.internal;

final class Import : Statement {
    string aliasName;   /// eg. cc
    string moduleName;  /// eg. core::c
    Module mod;

/// ASTNode
    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.IMPORT; }
///

    bool hasAliasName() { return aliasName !is null; }

    Function[] getFunctions(string name) {
        return children[].filter!(it=>it.id==NodeID.FUNCTION)
                         .map!(it=>cast(Function)it)
                         .filter!(it=>it.name==name)
                         .array;
    }
    Alias getAlias(string name) {
        foreach(c; children) {
            if(!c.isAlias) continue;
            auto a = c.as!Alias;
            if(a.name==name) return a;
        }
        return null;
    }

    override string toString() {
        string n = hasAliasName() ? ("'"~aliasName~"' ") : "";

        return "Import %s%s".format(n, moduleName);
    }
}