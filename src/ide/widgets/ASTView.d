module ide.widgets.ASTView;

import ide.internal;
import ppl2;

final class ASTView : TreeWidget {
private:
    IDE ide;

    int[int] nidToLine;
public:
    this(IDE ide) {
        super("AST-VIEW");
        this.ide = ide;

        fontSize = 16;

        selectionChange = (TreeItems source, TreeItem selectedItem, bool activated) {
            if(activated) {

                int line = nidToLine.get(selectedItem.id.to!int, -1);
                if(line!=-1) {
                    auto tab = ide.getEditorView().getSelectedTab();
                    if(tab) {
                        tab.setLine(line);
                    }
                }
            }
            selectedItem.expand();
            if(selectedItem.childCount>0) {
                if(selectedItem.child(0).text.indexOf("LITERAL_FUNCTION"d)!=-1 ||
                   selectedItem.child(0).text.indexOf("INITIALISER"d)!=-1)
                {
                    selectedItem.child(0).expand();
                }
            }
        };

    }
    void update(Module m) {
        clearAllItems();
        nidToLine.clear();

        auto rootItem = items.newChild(m.nid.to!string, "%s %s"d.format(m.id, m), null);

        void recurse(TreeItem item, ASTNode node) {
            foreach(n; node.children) {

                string ls;
                if(n.line!=-1) {
                    ls = "[%s] ".format(n.line+1);
                    nidToLine[n.nid] = n.line;
                }

                auto i = item.newChild(n.nid.to!string, "%s%s %s"d.format(ls, n.id, n), null);

                recurse(i, n);
            }
        }
        recurse(rootItem, m);

        rootItem.collapseAll();
        rootItem.expand();
    }
    void clear() {
        clearAllItems();
    }
}