module ide.widgets.editorview;

import ide.internal;

final class EditorView : TabWidget {
private:
    Project project;
    EditorTab[string] editors; // key = tab id
public:
    this() {
        super("EDITOR-VIEW");

        layoutWidth(FILL_PARENT);
        layoutHeight(FILL_PARENT);

        tabChanged = (string newTabId, string oldTabId) {
            auto t = editors[newTabId];
            dispatchAction(new Action(ActionID.WINDOW_CAPTION_CHANGE, ""d).stringParam(t.getFilename));
        };
        tabClose = (string tabId) {
            removeTab(tabId);
            editors.remove(tabId);
        };
    }
    void setProject(Project project) {
        this.project = project;


    }
    void loadFile(string name) {
        string filename = project.getAbsPath(name);
        assert(FQN!"std.file".exists(filename));

        auto tab = tab("TAB-"~name);
        if(!tab) {
            addTab(makeTab(name, filename), FQN!"std.path".baseName(name).toUTF32, null, true, null);
        }
        selectTab("TAB-"~name);

        //foreach(int i; 0..tabCount()) {
        //    writefln("[%s] %s", i, this.tab(i).id);
        //}
    }
private:
    Widget makeTab(string id, string filename) {
        auto editor = new EditorTab("TAB-"~id, filename);
        editors["TAB-"~id] = editor;

        //TabWidget subtabs = new TabWidget("TAB-"~id);
        //subtabs.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        //
        //subtabs.addTab(editor, "SRC"d, null, false, null);
        //subtabs.addTab(new TextWidget("tokens"~id, ""d), "Tokens"d, null, false, null);
        //subtabs.addTab(new TextWidget("ast"~id, ""d), "AST"d, null, false, null);
        //subtabs.addTab(new TextWidget("ir"~id, ""d), "IR"d, null, false, null);

        return editor;
    }
}
