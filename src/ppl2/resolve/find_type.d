module ppl2.resolve.find_type;

import ppl2.internal;

///
/// Look for a Define or NamedStruct with given name starting from node.
///
/// It is expected that this function is used during the parse phase so that
/// is why we treat all nodes within a literal function as possible targets.
/// This allows us to use the parent (literal function) to find a node which
/// wouldn't normally be necessary if we started from the node itself (which we may not have).
///
T findType(T)(string name, ASTNode node)
    if(is(T==Define) || is(T==NamedStruct))
{
    pragma(inline,true) T find(ASTNode n) {
        auto def = cast(T)n;
        if(def !is null && def.name==name) return def;
        return null;
    }

    auto nid = node.id();

    //dd("\t\tfindNode '%s' %s".format(name, node.id()));

    if(nid==NodeID.MODULE) {
        /// Check all module level nodes
        foreach(n; node.children) {
            auto def = find(n);
            if(def) return def;
        }
        return null;

    } else if(nid==NodeID.ANON_STRUCT || nid==NodeID.LITERAL_FUNCTION) {
        /// Check all scope level nodes
        foreach(n; node.children) {
            auto def = find(n);
            if(def) return def;
        }
        /// Recurse up the tree
        return findType!T(name, node.parent);

    }
    /// Check nodes that appear before 'node' in current scope
    foreach(n; node.prevSiblings()) {
        auto def = find(n);
        if (def) return def;
    }
    /// Recurse up the tree
    return findType!T(name, node.parent);
}
