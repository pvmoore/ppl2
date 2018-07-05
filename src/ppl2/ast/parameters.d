module ppl2.ast.parameters;

import ppl2.internal;
///
/// Wrap function parameters
///
final class Parameters : ASTNode {

    override bool isResolved() { return getParams().as!(ASTNode[]).areResolved; }
    override NodeID id() const { return NodeID.ARGUMENTS; }

    int numParams() const {
        return children.length.as!int;
    }
    string[] paramNames() {
        return getParams().map!(it=>it.name).array;
    }
    Type[] paramTypes() {
        return getParams().map!(it=>it.type).array;
    }
    Variable getParam(ulong index) {
        return getParams()[index];
    }
    Variable getParam(string name) {
        auto r = getParams().filter!(it=>it.name==name).takeOne;
        return r.empty ? null : r.front;
    }
    Variable[] getParams() {
        return children[].as!(Variable[]);
    }
    Function getFunction() {
        assert(parent.isLiteralFunction);
        return parent.as!LiteralFunction.getFunction();
    }

    ///
    /// This function is not global so requires the this* of the enclosing struct.
    ///
    void addThisParameter(NamedStruct ns) {
        // Poke the this* ptr into the start of the parameter list

        auto a = makeNode!Variable(ns);
        a.name = "this";
        a.type = PtrType.of(ns, 1);
        addToFront(a);
    }

    override string toString() {
        return "Parameters";
    }
}