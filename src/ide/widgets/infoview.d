module ide.widgets.infoview;

import ide.internal;

final class InfoView : TabWidget {
private:

public:
    this() {
        super("INFO-VIEW");

        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        addTab(new TextWidget("TOKENS-TAB", ""d), "Tokens"d, null, false, null);
        addTab(new TextWidget("AST-TAB", ""d), "AST"d, null, false, null);
        addTab(new TextWidget("IR-TAB", ""d), "IR"d, null, false, null);
    }
}

