module ide.widgets.ASTView;

import ide.internal;
import ppl2;

final class ASTView : TreeWidget {
private:
    IDE ide;
    string showingModule;
    int[int] nidToLine;
public:
    this(IDE ide) {
        super("AST-VIEW");
        this.ide = ide;

        fontSize = 15;

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
        };
    }
    void update(Module m, bool forceUpdate = false) {
        if(!forceUpdate && m.canonicalName==showingModule) return;

        showingModule = m.canonicalName;
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
    }
    void clear() {
        showingModule = null;
        clearAllItems();
    }
}