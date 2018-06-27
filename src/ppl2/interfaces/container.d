module ppl2.interfaces.container;

import ppl2.internal;
/**
 *  Variable or Function container.
 *
 *  Module, LiteralFunction, AnonStruct
 */
interface Container {
    NodeID id() const;

    final ASTNode node() { return cast(ASTNode)this; }
}
