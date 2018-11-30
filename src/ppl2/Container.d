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
}
