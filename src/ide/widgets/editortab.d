module ide.widgets.editortab;

import ide.internal;

final class EditorTab : SourceEdit {
private:
    ulong timerId;
public:
    string relFilename;
    string filename;
    bool isActive;

    this(string ID, string relFilename, string filename, int line) {
        super(ID);
        this.relFilename = relFilename;
        this.filename    = filename;

        //writefln("editorTab id:%s absFilename: %s line:%s", ID, filename, line);

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
            setTokenHightlightColor(TokenCategory.Identifier+5, 0xffaa44); /// function declarations

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
}
