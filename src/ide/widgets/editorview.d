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
            currentTab.onActivated(tab(newTabId));
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

        writefln("editorView.setProject"); flushConsole();

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
    void loadFile(string relPath) {
        string absPath = project.getAbsPath(relPath);
        assert(From!"std.file".exists(absPath), "file not found");

        //writefln("loadFile %s %s", relPath, filename); flushConsole();

        auto openFile = project.getOpenFile(relPath);

        auto t = tab("TAB-"~relPath);
        if(!t) {
            auto widget = makeTab(relPath, absPath, openFile);
            addTab(widget, getLabel(relPath), null, true, null);
        } else {

        }
        selectTab("TAB-"~relPath);

        //foreach(int i; 0..tabCount()) {
        //    writefln("[%s] %s", i, this.tab(i).id);
        //}
    }
private:
    dstring getLabel(string relPath) {
        auto label  = From!"std.path".baseName(relPath).toUTF32;
        foreach(int i; 0..tabCount()) {
            if(tab(i).text == label) {
                return relPath.toUTF32;
            }
        }
        return label;
    }
    Widget makeTab(string relPath, string absPath, Project.OpenFile* info) {
        int line = 0;
        if(info) {
            line = info.line;
        }

        auto editor = new EditorTab(ide, "TAB-"~relPath, relPath, absPath, line);
        editors["TAB-"~relPath] = editor;

        return editor;
    }
}
