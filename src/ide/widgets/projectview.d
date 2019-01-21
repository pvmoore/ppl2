module ide.widgets.projectview;

import ide.internal;

final class ProjectView : TreeWidget {
private:
    IDE ide;
    Project project;
    TreeItem[string] nodes;
    TreeItem[string] leaves;
public:
    this(IDE ide) {
        super("PROJECT-VIEW");
        this.ide = ide;

        //items.selectItem(tree1);
        //
        //tree1.expand();
        ////tree1.collapse();
        //
        //tree1.expandAll();
        //tree1.isVisible;
        //
        //tree1.isSelected;
        //tree1.root.selectItem();

        selectionChange = (TreeItems source, TreeItem selectedItem, bool activated) {
            if(activated) {
                dispatchAction(new Action(ActionID.PROJECT_VIEW_FILE_ACTIVATED, ""d).stringParam(selectedItem.id));
            }

        };
    }
    void onClosing() {

    }
    void refresh() {

    }
    void setProject(Project project) {
        import std.file, std.path;

        writefln("projectView.setProject"); flushConsole();

        if(nodes.length>0) {
            nodes.clear();
            leaves.clear();

            clearAllItems();
        }

        void makeNode(string name) {
            nodes[name] = items.newChild(name, name.toUTF32);
            //TreeItem item;
        }
        void makeLeaf(string name) {
            auto folder = dirName(name) ~ "/";
            if(nodes.containsKey(folder)) {
                nodes[name] = nodes[folder].newChild(name, name.baseName.toUTF32);
            } else {
                nodes[name] = items.newChild(name, name.toUTF32);
            }
        }

        auto processedDirectories = new Set!string;

        void processDirectory(string directory) {
            if(processedDirectories.contains(directory)) return;
            processedDirectories.add(directory);
            //writefln("processDir %s", directory);

            lp:foreach(DirEntry e; dirEntries(directory, SpanMode.breadth)) {

                string rel = asRelativePath(e.name, directory).array.replace("\\", "/");
                if(e.isDir) {
                    rel ~= "/";
                } else {
                    if(!e.name.endsWith(".p2")) continue lp;
                }

                foreach(excl; project.excludeDirectories) {
                    if(rel.startsWith(excl)) continue lp;
                }
                foreach(excl; project.excludeFiles) {
                    if(rel.endsWith(excl)) continue lp;
                }

                if(e.isDir) {
                    makeNode(rel);
                } else {
                    makeLeaf(rel);
                }
            }
        }
        processDirectory(project.directory);

        foreach(inc; project.config.getIncludes()) {
            processDirectory(inc.absPath);
        }

        foreach(n; nodes.values) {
            n.collapseAll();
        }
    }
}