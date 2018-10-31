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
    void log(A...)(dstring fmt, A args) {
        log(format(fmt, args));
    }
    void logln(A...)(dstring fmt, A args) {
        logln(format(fmt, args));
    }
    void logln(dstring s) {
        log(s~"\n"d);
    }
    void logln(string s) {
        log(s~"\n");
    }
    void log(dstring s) {
        scrollLock(true);
        appendText(s);
        scrollLock(false);
    }
    void log(string s) {
        scrollLock(true);
        appendText(s.toUTF32);
        scrollLock(false);
    }
    void clear() {
        content().text("");
    }
}