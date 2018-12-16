module ppl2.Container;

import ppl2.internal;
///
/// Variable or Function container.
///
/// Module, LiteralFunction, Struct, Tuple
///
interface Container {
    NodeID id() const;

    final ASTNode node() { return cast(ASTNode)this; }

    final bool isFunction() { return node().id==NodeID.LITERAL_FUNCTION; }
    final bool isModule()   { return node().id==NodeID.MODULE; }
    final bool isStruct()   { return node().id==NodeID.STRUCT; }
    final bool isTuple()    { return node().id==NodeID.TUPLE; }
}
