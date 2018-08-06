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

        auto comp = n.as!Composite;
        if(comp) {
            /// Treat children of Composite as if they were in scope
            foreach(ch; comp.children) {
                auto t = find(ch);
                if(t) return t;
            }
        }

        auto imp = n.as!Import;
        if(imp) {
            foreach(ch; imp.children) {
                auto t = find(ch);
                if(t) return t;
            }
        }
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
//====================================================================================
///
/// A more advanced findType function that handles template params
///
Type findType(string name, ASTNode node, Module module_, Type[] templateParams) {

    auto type = findType(name, node);
    if(!type) return null;

    assert(type.isDefine || type.isNamedStruct);

    auto def = type.getDefine;
    auto ns  = type.getNamedStruct;
    assert(def !is null || ns !is null);

    if(def) {
        defineRequired(def.moduleName, def.name);
    } else {
        defineRequired(ns.moduleName, ns.name);
    }

    if(templateParams.length>0) {
        if(ns && templateParams.areKnown) {
            string name2      = ns.name ~ "<" ~ mangle(templateParams) ~ ">";
            auto concreteType = findType(name2, node);
            if(concreteType) {
                /// We found the concrete impl
                return concreteType;
            }
        }

        /// Create a template proxy Define which can
        /// be replaced later by the concrete NamedStruct
        auto proxy                = makeNode!Define(node);
        proxy.name                = module_.makeTemporary("templateProxy");
        proxy.type                = TYPE_UNKNOWN;
        proxy.moduleName          = module_.canonicalName;
        proxy.isImport            = false;
        proxy.templateProxyType   = (ns ? ns : def).as!Type;
        proxy.templateProxyParams = templateParams;

        type = proxy;

        //dd("!!template proxy =", ns ? "NS:" ~ ns.name : "Def:" ~ def.name, templateParams);
    }

    return type;
}