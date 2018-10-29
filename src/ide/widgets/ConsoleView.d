module ide.widgets.ConsoleView;

import ide.internal;

final class ConsoleView : LogWidget {
private:
    IDE ide;
public:
    this(IDE ide) {
        this.ide = ide;

        fontSize = 14;
    }
    void logln(A...)(dstring fmt, A args) {
        try{
            appendText(format(fmt, args) ~ "\n"d);
        }catch(Exception e) {}
    }
    void logln(string s) {
        scrollLock(true);
        appendText(s.toUTF32 ~ "\n"d);
        scrollLock(false);
    }
    void clear() {
        content().text("");
    }
}