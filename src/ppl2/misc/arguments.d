module ppl2.misc.arguments;

import ppl2.internal;
///
/// Wrap function arguments.
///
final class Arguments : ASTNode {

    override bool isResolved() { return getArgs().as!(ASTNode[]).areResolved; }
    override NodeID id() const { return NodeID.ARGUMENTS; }

    int numArgs() const {
        return children.length.as!int;
    }
    string[] argNames() {
        return getArgs().map!(it=>it.name).array;
    }
    Type[] argTypes() {
        return getArgs().map!(it=>it.type).array;
    }
    Variable getArg(ulong index) {
        return getArgs()[index];
    }
    Variable getArg(string name) {
        auto r = getArgs().filter!(it=>it.name==name).takeOne;
        return r.empty ? null : r.front;
    }
    Variable[] getArgs() {
        return children[].as!(Variable[]);
    }

    ///
    /// This function is not global so requires the this* of the enclosing struct.
    ///
    void addThisParameter(NamedStruct ns) {
        // Poke the this* ptr into the start of the argument list

        auto a = makeNode!Variable(ns);
        a.name = "this";
        a.type = PtrType.of(ns, 1);
        addToFront(a);
    }

    override string toString() {
        return "Arguments";
    }
}