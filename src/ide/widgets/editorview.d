module ide.widgets.editorview;

import ide.internal;

final class EditorView : TabWidget {
private:
    IDE ide;
    Project project;
    EditorTab[/*tab id*/string] editors;
    EditorTab currentTab;
public:
    this(IDE ide) {
        super("EDITOR-VIEW");
        this.ide = ide;

        tabChanged = (string newTabId, string oldTabId) {
            auto oldTab = editors.get(oldTabId, null);
            currentTab  = editors[newTabId];
            dispatchAction(new Action(ActionID.WINDOW_CAPTION_CHANGE, ""d).stringParam(currentTab.filename));

            if(oldTab) oldTab.onDeactivated();
            currentTab.onActivated();
        };
        tabClose = (string tabId) {
            removeTab(tabId);
            editors.remove(tabId);
        };
    }
    EditorTab getSelectedTab() {
        return currentTab;
    }
    EditorTab getTabByCanonicalName(string canonicalName) {
        foreach(e; editors.values) {
            if(e.moduleCanonicalName==canonicalName) return e;
        }
        return null;
    }
    void onClosing() {
        if(!project) return;

        saveAll();

        /// update the open files and caret lines
        Project.OpenFile[] openFiles;
        foreach(e; editors.values) {
            openFiles ~= Project.OpenFile(e.relFilename, e.caretPos.line, e.isActive);
        }
        project.updateOpenFiles(openFiles);
    }
    void saveAll() {
        foreach(e; editors.values) {
            if(e.content().modified) {
                e.save(e.filename);
            }
        }
    }
    void setProject(Project project) {
        this.project = project;

        /// Remove all current tabs
        foreach(i; editors.keys) {
            removeTab(i);

        }
        editors.clear();

        /// Open project tabs
        foreach(f; project.openFiles.keys) {
            dispatchAction(new Action(ActionID.PROJECT_VIEW_FILE_ACTIVATED, ""d).stringParam(f));
        }
        auto active = project.getActiveOpenFile();
        if(active) {
            selectTab("TAB-"~active.filename);
        }
    }
    void loadFile(string name) {
        string filename = project.getAbsPath(name);
        assert(FQN!"std.file".exists(filename));

        //writefln("loadFile %s %s", name, filename); flushConsole();

        auto openFile = project.getOpenFile(name);

        auto t = tab("TAB-"~name);
        if(!t) {
            addTab(makeTab(name, filename, openFile), FQN!"std.path".baseName(name).toUTF32, null, true, null);
        }
        selectTab("TAB-"~name);

        //foreach(int i; 0..tabCount()) {
        //    writefln("[%s] %s", i, this.tab(i).id);
        //}
    }
private:
    Widget makeTab(string name, string filename, Project.OpenFile* info) {
        int line = 0;
        if(info) {
            line = info.line;
        }

        auto editor = new EditorTab(ide, "TAB-"~name, name, filename, line);
        editors["TAB-"~name] = editor;
        return editor;
    }
}
