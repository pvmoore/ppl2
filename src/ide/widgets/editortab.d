module ide.widgets.editortab;

import ide.internal;

final class EditorTab : SourceEdit {
private:
    string filename;
public:
    string getFilename() { return filename; }

    this(string ID, string filename) {
        super(ID);
        this.filename = filename;

        MenuItem contextMenu = new MenuItem(null);
        contextMenu.add(new Action(ActionID.CONTEXT_MENU, "Context Menu"d));
        popupMenu = contextMenu;

        //fontFace = "Courier New";
        fontFamily = FontFamily.MonoSpace;
        fontSize   = makePointSize(14);
        //fontWeight = FontWeight.Bold;
        minFontSize(10).maxFontSize(30);

        import dlangui.dml.dmlhighlight;
        DMLSyntaxSupport dml;

        //0x00d0d0 cyan
        // 0x008000 green

        setTokenHightlightColor(TokenCategory.Comment, 0x707070);
        setTokenHightlightColor(TokenCategory.Comment_SingleLine, 0x907070);
        setTokenHightlightColor(TokenCategory.Comment_MultyLine, 0x909070);

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

        useSpacesForTabs = true;
        showLineNumbers = true;
        showModificationMarks = true;
        showFolding = true;
        showIcons = true;
        tabSize = 4;

        load(filename);

        content.syntaxSupport = new PPL2SyntaxSupport;
    }
}
