module ppl2.interfaces;

import ppl2.internal;
///
/// Variable or Function container.
///
/// Module, LiteralFunction, Tuple
///
interface Container {
    NodeID id() const;

    final ASTNode node() { return cast(ASTNode)this; }
}
