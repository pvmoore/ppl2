module ide.ide;

import ide.internal;

final class IDE : AppFrame {
private:
    MenuItem menuBar;
    StatusLine statusLine;
    Window window;
    ProjectView projectView;
    EditorView editorView;
    InfoView infoView;
    ConsoleView consoleView;
    Project project;
public:
    auto getConsole() { return consoleView; }
    auto getInfoView() { return infoView; }
    Project getProject() { return project; }

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
            new Action(ActionID.TOOLBAR_BUILD_MODULE, "Build Module"d),
            ACTION_SEPARATOR,
            new Action(ActionID.TOOLBAR_BUILD_PROJECT, "Build Project"d));

        /// Force actions to be dispatched to our main handleAction method
        foreach(i; 0..tb.childCount) {
            auto button = cast(Button)tb.child(i);
            if(button) {
                button.click = (Widget src) {
                    dispatchAction(src.action); return true;
                };
            }
        }

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
                case TOOLBAR_BUILD_MODULE:
                    auto tab = editorView.getSelectedTab();
                    tab.build();
                    break;
                case TOOLBAR_BUILD_PROJECT:
                    break;
                default:
                    writefln("handleAction: Missing handler for id %s", cast(ActionID)a.id);
                    break;
            }
        }
        writefln("action %s handled", cast(ActionID)a.id); flushConsole();
        return true;
    }
    override Widget createBody() {
        projectView = new ProjectView(this);
        editorView  = new EditorView(this);
        infoView    = new InfoView(this);
        consoleView = new ConsoleView(this);

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