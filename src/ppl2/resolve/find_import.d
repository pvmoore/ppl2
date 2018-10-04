module ppl2.resolve.find_import;

import ppl2.internal;

///
/// Look for an Import node
///
Import findImportByCanonicalName(string canonicalName, ASTNode node) {

    /// Check nodes that appear before 'node' in current scope
    foreach(n; node.prevSiblings()) {
        auto imp = n.as!Import;
        if(imp && imp.moduleName==canonicalName) {
            return imp;
        }
    }
    if(node.parent) {
        /// Recurse up the tree
        return findImportByCanonicalName(canonicalName, node.parent);
    }
    return null;
}
Import findImportByAlias(string alias_, ASTNode node) {
    /// Check nodes that appear before 'node' in current scope
    foreach(n; node.prevSiblings()) {
        auto imp = n.as!Import;
        if(imp && alias_==imp.aliasName) {
            return imp;
        }
    }
    if(node.parent) {
        /// Recurse up the tree
        return findImportByAlias(alias_, node.parent);
    }
    return null;
}
