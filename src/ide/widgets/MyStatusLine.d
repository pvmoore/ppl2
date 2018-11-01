module ide.widgets.MyStatusLine;

import ide.internal;

final class MyStatusLine : StatusLine {
private:
    IDE ide;
public:
    this(IDE ide) {
        this.ide = ide;
        setStatusText("Ok");
    }
    void setBuildStatus(string text, ulong nanos) {
        setStatusText("%s   (%.2f seconds)"d.format(text, nanos * 1e-9));
    }
}