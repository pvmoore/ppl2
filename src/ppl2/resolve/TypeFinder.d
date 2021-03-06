module ppl2.resolve.TypeFinder;

import ppl2.internal;

final class TypeFinder {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    ///
    /// Look for a Alias, Enum or Struct with given name starting from node.
    ///
    /// It is expected that this function is used during the parse phase so that
    /// is why we treat all nodes within a literal function as possible targets.
    /// This allows us to use the parent (literal function) to find a node which
    /// wouldn't normally be necessary if we started from the node itself (which we may not have).
    ///
    Type findType(string name, ASTNode node, bool isInnerType = false) {

        Type find(ASTNode n) {
            auto def = n.as!Alias;
            if(def && def.name==name) return def;

            auto ns = n.as!Struct;
            if(ns && ns.name==name) return ns;

            auto en = n.as!Enum;
            if(en && en.name==name) return en;

            auto comp = n.as!Composite;
            if(comp) {
                /// Treat children of Composite as if they were in scope
                foreach(ch; comp.children) {
                    auto t = find(ch);
                    if(t) return t;
                }
            }

            auto imp = n.as!Import;
            if(imp && !imp.hasAliasName) {
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
            foreach (n; node.children) {
                auto t = find(n);
                if (t) return found(t);
            }
            return null;

        } else if(nid==NodeID.TUPLE || nid==NodeID.STRUCT || nid==NodeID.LITERAL_FUNCTION) {
            /// Check all scope level nodes
            foreach(n; node.children) {
                auto t = find(n);
                if(t) return found(t);
            }
            /// If we are looking for an inner type then we haven't found it
            if(isInnerType) {
                return null;
            }

            /// Recurse up the tree
            return findType(name, node.parent);
        }
        /// Check nodes that appear before 'node' in current scope
        foreach(n; node.prevSiblings()) {
            auto t = find(n);
            if(t) return found(t);
        }
        /// Recurse up the tree
        return findType(name, node.parent);
    }
    ///
    /// A more advanced findType function that handles template params
    ///
    Type findTemplateType(Type untemplatedType, ASTNode node, Type[] templateParams) {
        auto type = untemplatedType;

        assert(templateParams.length>0);
        assert(type && (type.isAlias || type.isStruct));

        auto alias_ = type.getAlias;
        auto ns     = type.getStruct;
        assert(alias_ !is null || ns !is null);

        found(type);

        if(ns && templateParams.areKnown) {
            string name2      = ns.name ~ "<" ~ module_.buildState.mangler.mangle(templateParams) ~ ">";
            auto concreteType = findType(name2, node);
            if(concreteType) {
                /// We found the concrete impl
                return concreteType;
            }
        }

        /// Create a template proxy Alias which can
        /// be replaced later by the concrete Struct
        auto proxy           = makeNode!Alias(node);
        proxy.name           = module_.makeTemporary("templateProxy");
        proxy.type           = type;
        proxy.moduleName     = module_.canonicalName;
        proxy.isImport       = false;
        proxy.templateParams = templateParams;

        type = proxy;

        //dd("!!template proxy =", ns ? "NS:" ~ ns.name : "Def:" ~ def.name, templateParams);

        return type;
    }
    private Type found(Type t) {

        auto alias_ = t.getAlias;
        auto ns     = t.getStruct;
        auto en     = t.getEnum;
        assert(alias_ !is null || ns !is null || en !is null);

        if(alias_) {
            module_.buildState.aliasEnumOrStructRequired(alias_.moduleName, alias_.name);
        } else if(en) {
            module_.buildState.aliasEnumOrStructRequired(en.moduleName, en.name);
            en.numRefs++;
        } else {
            module_.buildState.aliasEnumOrStructRequired(ns.moduleName, ns.name);
            ns.numRefs++;
        }

        return t;
    }
}
