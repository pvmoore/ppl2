module ide.widgets.ASTView;

import ide.internal;
import ppl2;

final class ASTView : TreeWidget {
private:
    IDE ide;
public:
    this(IDE ide) {
        super("AST-VIEW");
        this.ide = ide;

        fontSize = 15;
    }
    void update(Module m) {
        clearAllItems();

        auto rootItem = items.newChild(m.nid.to!string, "%s %s"d.format(m.id, m), null);

        void recurse(TreeItem item, ASTNode node) {
            foreach(n; node.children) {
                auto i = item.newChild(n.nid.to!string, "%s %s"d.format(n.id, n), null);
                recurse(i, n);
            }
        }
        recurse(rootItem, m);
    }
}