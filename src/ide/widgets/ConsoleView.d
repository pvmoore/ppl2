module ide.widgets.ConsoleView;

import ide.internal;

final class ConsoleView : LogWidget {
private:

public:
    this() {

    }
    void logln(A...)(dstring fmt, A args) {
        try{
            appendText(format(fmt, args) ~ "\n"d);
        }catch(Exception e) {}
    }
    void clear() {
        content().text("");
    }
}