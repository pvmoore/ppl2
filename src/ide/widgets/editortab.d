module ide.widgets.editortab;

import ide.internal;
import ppl2;

final class EditorTab : SourceEdit {
private:
    IDE ide;
    TabItem tabItem;
    ulong timerId;
    Project project;
    //ModuleBuilder builder;
    StopWatch timeSinceLastEdit;
public:
    string relFilename;
    string filename;
    string moduleCanonicalName;
    bool isActive;

    this(IDE ide, string ID, string relFilename, string filename, int line) {
        super(ID);
        this.ide                 = ide;
        this.relFilename         = relFilename;
        this.filename            = filename;
        this.project             = ide.getProject();
        //this.builder             = PPL2.instance().createModuleBuilder(project.config);

        import std.path;
        this.moduleCanonicalName = stripExtension(relFilename).replace("/", "::");

        MenuItem contextMenu = new MenuItem(null);
        contextMenu.add(new Action(ActionID.CONTEXT_MENU, "Context Menu"d));
        popupMenu = contextMenu;

        //int x = 10, y=10;
        //canShowPopupMenu(x,y);
        //showPopupMenu(x,y);

        //fontFace = "Courier New";
        fontFamily = FontFamily.MonoSpace;
        fontSize   = makePointSize(14);
        //fontWeight = FontWeight.Bold;
        minFontSize(10).maxFontSize(30);

        load(filename);

        useSpacesForTabs      = true;
        showLineNumbers       = true;
        showModificationMarks = true;
        showFolding           = true;
        showIcons             = true;
        tabSize               = 4;

        import dlangui.dml.dmlhighlight;
        DMLSyntaxSupport dml;

        if(filename.endsWith(".p2")) {

            setTokenHightlightColor(TokenCategory.Comment, 0x707070);
            setTokenHightlightColor(TokenCategory.Comment_SingleLine, 0x504040);
            setTokenHightlightColor(TokenCategory.Comment_MultyLine, 0x405040);

            setTokenHightlightColor(TokenCategory.Keyword, 0xAD83D7);
            setTokenHightlightColor(TokenCategory.Keyword | 1, 0xAD83D7 - 0x606060);
            setTokenHightlightColor(TokenCategory.Keyword | 2, 0xFF8800);

            setTokenHightlightColor(TokenCategory.String, 0x008000);
            setTokenHightlightColor(TokenCategory.Character, 0xd0d000);
            setTokenHightlightColor(TokenCategory.Integer, 0xd0d000);
            setTokenHightlightColor(TokenCategory.Float, 0xd0d000);
            setTokenHightlightColor(TokenCategory.Error, 0xFF0000);
            setTokenHightlightColor(TokenCategory.Op, 0xc7c7c7);

            setTokenHightlightColor(TokenCategory.Identifier, 0xffffff);
            setTokenHightlightColor(TokenCategory.Identifier_Class, 0xffffff);
            setTokenHightlightColor(TokenCategory.Identifier|5, 0xffaa44); /// function declarations

            auto syntaxSupport = new PPL2SyntaxSupport(moduleCanonicalName);
            ide.addBuildListener(syntaxSupport);

            content.syntaxSupport = syntaxSupport;

            content.smartIndents = true;
        } else {
            /// Not a p2 file
        }
        setFocus();
        setLine(line);

        modifiedStateChange.connect(delegate(Widget source, bool modified) {
            if(modified) {

            } else {

            }
        });
        contentChange.connect((EditableContent source) {
            timeSinceLastEdit.reset();
            timeSinceLastEdit.start();
        });
        editorStateChange.connect((Widget source, ref EditorStateInfo editorState) {

        });
    }
    void onActivated(TabItem t) {
        tabItem  = t;
        isActive = true;
        timeSinceLastEdit.reset();
        //timeSinceLastEdit.start();

        if(timerId==0) {
            timerId = setTimer(1000);
        }

        auto b = ide.getBuildState();
        if(b) {
            auto m          = b.getModule(moduleCanonicalName);
            auto infoView   = ide.getInfoView();
            auto tokensView = infoView.getTokensView();
            auto astView    = infoView.getASTView();
            auto irView     = infoView.getIRView();
            auto optIrView  = infoView.getOptIRView();

            if(m) {
                tokensView.update(m.parser.getInitialTokens()[]);
                astView.update(m);
                irView.update(b.getUnoptimisedIR(moduleCanonicalName));
                optIrView.update(b.getOptimisedIR(moduleCanonicalName));
            } else {
                tokensView.clear();
                astView.clear();
                irView.update("");
                optIrView.update("");
            }
        }
    }
    void onDeactivated() {
        isActive = false;
        timeSinceLastEdit.stop();
    }
    void setLine(int line) {
        setCaretPos(line-10, 0, true, true);
        setCaretPos(line   , 0, false, false);
    }
    override bool onKeyEvent(KeyEvent event) {
        if(event.action==KeyAction.KeyDown) {
            if(event.modifiers & KeyFlag.Control) {
                if(event.keyCode==KeyCode.KEY_S) {
                    save(filename);
                    dispatchAction(new Action(ActionID.TOOLBAR_BUILD_OPT_PROJECT));
                    return true;
                }
            }
        }
        return super.onKeyEvent(event);
    }
    override bool onTimer(ulong id) {
        if(id!=timerId) return false;
        if(!isActive) return false;

        auto seconds = timeSinceLastEdit.peek().total!"seconds";
        //writefln("seconds=%s", seconds); flushConsole();
        if(seconds > 5) {

            //dispatchAction(new Action(ActionID.TOOLBAR_BUILD_OPT_PROJECT));

            /// Reset clock and stop it. Any edit will restart it
            timeSinceLastEdit.reset();
            timeSinceLastEdit.stop();
        }
        return true;
    }
    override string toString() {
        return "[EditorTab %s]".format(moduleCanonicalName);
    }
    void build() {
        //ide.getConsole().logln("Building module '%s' ... ", moduleCanonicalName);
        //
        //auto info = ide.getInfoView();
        //auto src  = convertTabsToSpaces(content().text().toUTF8);
        //
        //builder.startNewBuild();
        //
        //auto m = builder.getOrCreateModule(moduleCanonicalName, src);
        //
        //if(builder.build(m)) {
        //    info.getTokensView().update(m.parser.getInitialTokens()[]);
        //    info.getASTView().update(m);
        //    info.getIRView().update(builder.getUnoptimisedIR());
        //    info.getOptIRView().update(builder.getOptimisedIR());
        //
        //    ide.getConsole().logln("References   : %s", m.getReferencedModules().map!(it=>it.canonicalName));
        //    ide.getConsole().logln("Referencedby : %s", builder.allModulesThatReference(m).map!(it=>it.canonicalName));
        //
        //} else {
        //    ide.getConsole().logln("Unresolved = %s", m.resolver.getUnresolvedNodes);
        //}
        //
        //builder.dumpStats((string it)=>ide.getConsole().logln(it));
    }
}
