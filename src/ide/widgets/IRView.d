module ide.widgets.IRView;

import ide.internal;

final class IRView : SourceEdit {
private:
    IDE ide;
public:
    this(string id, IDE ide) {
        super(id);
        this.ide = ide;

        fontSize = 16;
        readOnly(true);

        setTokenHightlightColor(TokenCategory.Comment, 0x707070);
        setTokenHightlightColor(TokenCategory.Op, 0xffffff);

        setTokenHightlightColor(TokenCategory.Identifier,        0xaaaaaa);
        setTokenHightlightColor(TokenCategory.Identifier_Local,  0x77aa77);
        setTokenHightlightColor(TokenCategory.Identifier_Member, 0xaacc44);
        setTokenHightlightColor(TokenCategory.Identifier|5,      0xad83d7);  /// type
        setTokenHightlightColor(TokenCategory.Identifier|6,      0xff7788);  /// label

        setTokenHightlightColor(TokenCategory.Keyword, 0x44aaff);
        setTokenHightlightColor(TokenCategory.Integer, 0xd0d000);
        setTokenHightlightColor(TokenCategory.String, 0x008000);

        content.syntaxSupport = new IRSyntaxSupport;
    }
    void update(string str) {
        text(str.toUTF32);
    }
}