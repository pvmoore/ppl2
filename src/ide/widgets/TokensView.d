module ide.widgets.TokensView;

import ide.internal;
import ppl2;

final class TokensView : EditBox {
private:
    IDE ide;
public:
    this(IDE ide) {
        super("TOKENS-VIEW");
        this.ide = ide;

        fontSize = 15;
        readOnly(true);
    }
    void update(ppl2.Token[] tokens) {
        auto buf = new StringBuffer;
        foreach(i, token; tokens) {
            buf.add("[% 4s] %s\n".format(i, token));
        }
        text(buf.toString().toUTF32);
        //readOnly(true);
    }
    void clear() {
        text(""d);
    }
}