module ide.widgets.projectview;

import ide.internal;

final class ProjectView : TreeWidget {
private:
    Project project;
    TreeItem[string] nodes;
    TreeItem[string] leaves;
public:
    this() {
        super("PROJECT-VIEW");

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
    void refresh() {

    }
    void setProject(Project project) {
        import std.file, std.path;

        if(nodes.length>0) {
            assert(false, "TODO - clear items before setting project again");
        }

        void makeNode(string name) {
            nodes[name] = items.newChild(name, name.toUTF32);
        }
        void makeLeaf(string name) {
            auto folder = dirName(name) ~ "/";
            if(nodes.containsKey(folder)) {
                nodes[name] = nodes[folder].newChild(name, name.baseName.toUTF32);
            } else {
                nodes[name] = items.newChild(name, name.toUTF32);
            }
        }
        void processDirectory(string directory) {
            //writefln("processDir %s", directory);
            lp:foreach (DirEntry e; dirEntries(directory, SpanMode.breadth)) {
                string rel = asRelativePath(e.name, directory).array.replace("\\", "/");
                if(e.isDir) rel ~= "/";

                foreach (excl; project.excludedDirs) {
                    if(rel.startsWith(excl)) continue lp;
                }
                foreach (excl; project.excludedFiles) {
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
        foreach(lib; project.libs.values) {
            processDirectory(lib);
        }

        foreach(n; nodes.values) {
            n.collapseAll();
        }
    }
}