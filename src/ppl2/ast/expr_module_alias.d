module ppl2.ast.expr_module_alias;

import ppl2.internal;

final class ModuleAlias : Expression {
    Module mod;
    Import imp;

    override bool isResolved() { return mod.isParsed; }
    override bool isConst() { return true; }
    override NodeID id() const { return NodeID.MODULE_ALIAS; }
    override int priority() const { return 15; }
    override Type getType() { return TYPE_VOID; }

    override string toString() {
        return "ModuleAlias (%s)".format(mod.canonicalName);
    }
}