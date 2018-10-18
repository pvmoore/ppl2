module ide.ide;

import ide.internal;

final class IDE : AppFrame {
private:
    MenuItem menuBar;
    StatusLine statusLine;
    Window window;
    DockWindow projectDock, propertiesDock;

    ProjectView projectView;
    EditorView editorView;
    InfoView infoView;

    Project project;
public:
    this(string[] args, Window window) {
        this.window = window;
    }
    void ready() {
        loadProject();
        assert(project);
    }
protected:
    override MainMenu createMainMenu() {
        menuBar = new MenuItem();

        MenuItem file = new MenuItem(new Action(1, "File"d));
        file.add(new Action(ActionID.FILE_EXIT, "Exit"d));
        file.add(new MenuItem().type(MenuItemType.Separator));
        file.add(new Action(ActionID.FILE_OPEN_PROJECT, "Open Project"d));

        MenuItem help = new MenuItem(new Action(ActionID.HELP_MENU, "Help"d));
        help.add(new Action(ActionID.HELP_ABOUT, "About"d));

        menuBar.add(file);
        menuBar.add(help);

        return new MainMenu(menuBar);
    }
    override ToolBarHost createToolbars() {
        //ToolBarHost res = new ToolBarHost();
        //ToolBar tb;
        //tb = res.getOrAddToolbar("Standard");
        //tb.addButtons(ACTION_FILE_NEW, ACTION_FILE_OPEN, ACTION_FILE_SAVE, ACTION_SEPARATOR, ACTION_DEBUG_START);
        //
        //tb = res.getOrAddToolbar("Edit");
        //tb.addButtons(ACTION_EDIT_COPY, ACTION_EDIT_PASTE, ACTION_EDIT_CUT, ACTION_SEPARATOR,
        //ACTION_EDIT_UNDO, ACTION_EDIT_REDO, ACTION_EDIT_INDENT, ACTION_EDIT_UNINDENT);
        return null;
    }
    override StatusLine createStatusLine() {
        statusLine = new StatusLine;
        statusLine.setStatusText("Ok");
        return statusLine;
    }
    override bool handleAction(const Action a) {
        if(a) {
            switch(a.id) with(ActionID) {
                case FILE_EXIT:
                    window.close();
                    break;
                case PROJECT_VIEW_FILE_ACTIVATED:
                    editorView.loadFile(a.stringParam);
                    break;
                case WINDOW_CAPTION_CHANGE:
                    window.windowCaption = "PPL IDE :: %s"d.format(a.stringParam);
                    break;
                default:
                    writefln("handleAction: Missing handler for id %s", cast(ActionID)a.id);
                    break;
            }
        }
        return true;
    }
    override Widget createBody() {
        projectView = new ProjectView;
        editorView  = new EditorView;
        infoView    = new InfoView;

        auto dock = new DockHost("dockhost");

        projectDock = new DockWindow("dockleft");
        projectDock.bodyWidget = projectView;
        projectDock.dockAlignment = DockAlignment.Left;
        projectDock.child(0).child(0).text = "Project"d;
        dock.addDockedWindow(projectDock);

        propertiesDock = new DockWindow("dockright");
        propertiesDock.bodyWidget = infoView;
        propertiesDock.dockAlignment = DockAlignment.Right;
        propertiesDock.child(0).child(0).text = "Info"d;
        dock.addDockedWindow(propertiesDock);

        dock.bodyWidget = editorView;

        return dock;
    }
private:
    void loadProject() {
        project = new Project;

        projectView.setProject(project);
        editorView.setProject(project);

        //window.windowCaption = "PPL IDE :: %s :: %s"d.format(project.name, project.directory);
        projectDock.child(0).child(0).text = "Project :: %s"d.format(project.name);
    }
}