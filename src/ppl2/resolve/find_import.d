module ppl2.resolve.find_import;

import ppl2.internal;

///
/// Look for an Import node
///
Import findImport(string name, ASTNode node) {

    /// Check nodes that appear before 'node' in current scope
    foreach(n; node.prevSiblings()) {
        auto imp = n.as!Import;
        if(imp && imp.moduleName==name) {
            return imp;
        }
    }
    if(node.parent) {
        /// Recurse up the tree
        return findImport(name, node.parent);
    }
    return null;
}
