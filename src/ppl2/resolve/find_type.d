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
Type findType(string name, ASTNode node) {
    pragma(inline,true) Type find(ASTNode n) {
        auto def = n.as!Define;
        if(def && def.name==name) return def;
        auto ns = n.as!NamedStruct;
        if(ns && ns.name==name) return ns;
        return null;
    }

    auto nid = node.id();

    //dd("\t\tfindNode '%s' %s".format(name, node.id()));

    if(nid==NodeID.MODULE) {
        /// Check all module level nodes
        foreach(n; node.children) {
            auto t = find(n);
            if(t) return t;
        }
        return null;

    } else if(nid==NodeID.ANON_STRUCT || nid==NodeID.LITERAL_FUNCTION) {
        /// Check all scope level nodes
        foreach(n; node.children) {
            auto t = find(n);
            if(t) return t;
        }
        /// Recurse up the tree
        return findType(name, node.parent);

    }
    /// Check nodes that appear before 'node' in current scope
    foreach(n; node.prevSiblings()) {
        auto t = find(n);
        if(t) return t;
    }
    /// Recurse up the tree
    return findType(name, node.parent);
}
