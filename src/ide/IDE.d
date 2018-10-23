module ide.ide;

import ide.internal;

final class IDE : AppFrame {
private:
    MenuItem menuBar;
    StatusLine statusLine;
    Window window;
    //DockWindow projectDock, propertiesDock;

    ProjectView projectView;
    EditorView editorView;
    InfoView infoView;
    ConsoleView consoleView;

    Project project;
public:
    this(string[] args, Window window) {
        this.window = window;
    }
    void ready() {
        loadProject();
        assert(project);

        //executeInUiThread(() {
        //    writefln("hello there ui thread %s", Thread.getThis.id); flushConsole();
        //    //window.showMessageBox("Title"d, "Content"d, [ACTION_OK]);
        //});
        //window.onCanClose(() {
        //    return true;
        //});
        window.onClose(() {
            if(projectView) projectView.onClosing();
            if(editorView) editorView.onClosing();
            if(project) project.save();
        });
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
        ToolBarHost res = new ToolBarHost();
        ToolBar tb;
        tb = res.getOrAddToolbar("Build");
        tb.addButtons(
            new Action(ActionID.TOOLBAR_TOKENISE, "Tokenise"d),
            ACTION_SEPARATOR,
            new Action(ActionID.TOOLBAR_PARSE, "Parse"d),
            ACTION_SEPARATOR,
            new Action(ActionID.TOOLBAR_RESOLVE, "Resolve"d));

        assert(cast(Button)tb.child(0));
        assert(cast(Button)tb.child(2));
        assert(cast(Button)tb.child(4));

        tb.child(0).click = (Widget src) {
            consoleView.logln("Tokenising... %s", 99);
            return true;
        };
        tb.child(2).click = (Widget src) {
            consoleView.logln("Parsing...");
            return true;
        };
        tb.child(4).click = (Widget src) {
            consoleView.logln("Resolving...");
            return true;
        };

        //tb = res.getOrAddToolbar("Edit");
        //tb.addButtons(
        //    new Action(ActionID.TOOLBAR_TOKENISE, "One"d),
        //    ACTION_SEPARATOR,
        //    new Action(ActionID.TOOLBAR_TOKENISE, "Two"d)
        //);
        return res;
    }
    override StatusLine createStatusLine() {
        statusLine = new StatusLine;
        statusLine.setStatusText("Ok");
        return statusLine;
    }
    override bool handleAction(const Action a) {
        writefln("handleAction: %s %s", a, cast(ActionID)a.id); flushConsole();
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
        consoleView = new ConsoleView;

        auto dock = new DockHost("dockhost");
        {
            auto d = new DockWindow("dockleft");
            d.bodyWidget = projectView;
            d.dockAlignment = DockAlignment.Left;
            d.child(0).child(0).text = "Project"d;
            dock.addDockedWindow(d);
        }
        {
            auto d = new DockWindow("dockright");
            d.bodyWidget = infoView;
            d.dockAlignment = DockAlignment.Right;
            d.child(0).child(0).text = "Info"d;
            dock.addDockedWindow(d);
        }
        {
            auto d = new DockWindow("dockbottom");
            d.bodyWidget = consoleView;
            d.dockAlignment = DockAlignment.Bottom;
            d.child(0).child(0).text = "Console"d;
            dock.addDockedWindow(d);
        }
        dock.bodyWidget = editorView;

        return dock;
    }
private:
    void loadProject() {
        project = new Project("test/");

        projectView.setProject(project);
        editorView.setProject(project);

        assert(cast(DockWindow)projectView.parent);
        projectView.parent.child(0).child(0).text = "Project :: %s"d.format(project.name);
    }
}