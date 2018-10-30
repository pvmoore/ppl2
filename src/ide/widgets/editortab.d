module ide.widgets.editortab;

import ide.internal;
import ppl2;

final class EditorTab : SourceEdit {
private:
    IDE ide;
    ulong timerId;
    BuildIncremental build;
    Project project;
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

        this.build = PPL2.instance().prepareAnIncrementalBuild(project.directory~project.mainFile);
        this.build.config.disableInternalLinkage = true;

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
            setTokenHightlightColor(TokenCategory.String, 0x008000);
            setTokenHightlightColor(TokenCategory.Character, 0xd0d000);
            setTokenHightlightColor(TokenCategory.Integer, 0xd0d000);
            setTokenHightlightColor(TokenCategory.Float, 0xd0d000);
            setTokenHightlightColor(TokenCategory.Error, 0xFF0000);
            setTokenHightlightColor(TokenCategory.Op, 0xc7c7c7);

            setTokenHightlightColor(TokenCategory.Identifier, 0xffffff);
            setTokenHightlightColor(TokenCategory.Identifier_Class, 0xffffff);
            setTokenHightlightColor(TokenCategory.Identifier|5, 0xffaa44); /// function declarations

            content.syntaxSupport = new PPL2SyntaxSupport;
        } else {
            /// Not a p2 file
        }
        setFocus();
        setCaretPos(line-10, 0, true, true);
        setCaretPos(line, 0, false, false);
    }
    void onActivated() {
        isActive = true;
        if(timerId==0) {
            timerId = setTimer(500);
        }
    }
    void onDeactivated() {
        isActive = false;
    }
    override bool onKeyEvent(KeyEvent event) {
        if(event.action==KeyAction.KeyDown) {
            if(event.modifiers & KeyFlag.Control) {
                if(event.keyCode==KeyCode.KEY_S) {
                    save(filename);
                    return true;
                }
            }
        }
        return super.onKeyEvent(event);
    }
    override bool onTimer(ulong id) {
        if(id!=timerId) return false;

        if(isActive) {
            //new Thread(() {
            //
            //}).start();
        }

        return true;
    }
    override string toString() {
        return "[EditorTab %s]".format(moduleCanonicalName);
    }
    void parse() {
        ide.getConsole().log("Parsing '%s' ... ", moduleCanonicalName);

        auto info = ide.getInfoView();
        auto src  = convertTabsToSpaces(content().text().toUTF8);

        try{
            /// If we get here then we have new content to parse
            build.startNewBuild();

            auto m = build.getOrCreateModule(moduleCanonicalName, src);
            ide.getConsole().logln("m=%s", m);

            info.getTokensView().update(m.parser.getInitialTokens()[]);

            build.parse(m);

            info.getASTView().update(m, true);

            build.resolve(m);

            ide.getConsole().logln("Unresolved = %s", m.resolver.getUnresolvedNodes);

            info.getASTView().update(m, true);

            ide.getConsole().logln("All symbols resolved");

            build.check(m);

            build.generateIR(m);

            info.getIRView().update(m.llvmValue.dumpToString());

            build.optimise(m);

            info.getOptIRView().update(m.llvmValue.dumpToString());

            build.dumpStats((string it)=>ide.getConsole().logln(it));

            ide.getConsole().logln("References   : %s", m.getReferencedModules().map!(it=>it.canonicalName));
            ide.getConsole().logln("Referencedby : %s", build.allModulesThatReference(m).map!(it=>it.canonicalName));

        }catch(CompilerError e) {
            ide.getConsole().logln("Compile error: [%s Line %s:%s] %s", e.module_.fullPath, e.line+1, e.column, e.msg);
        }catch(UnresolvedSymbols e) {
            ide.getConsole().logln("Unresolved symbols");
        }catch(Exception e) {
            ide.getConsole().logln("error: %s", e);
        }finally{
            ide.getConsole().logln("Status: %s", build.getStatus());
        }
    }
}
