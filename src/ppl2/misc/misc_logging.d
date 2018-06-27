module ppl2.misc.misc_logging;

import ppl2.internal;
import std.stdio    : File;
import std.file     : exists, mkdir;
import std.datetime	: Clock;

public:

void flushLogs() {
    flushConsole();
    if(g_logger) g_logger.flush();
}
void log(A...)(lazy string fmt, lazy A args) {
    if(g_logger) {
        g_logger.log(fmt, args);
        g_logger.flush();
    }
}

final class FileLogger {
    this(string filename) {
        this.filename = filename;
        this.file     = File(filename, "w");
    }
    ~this() {
        file.close();
    }
    void flush() nothrow {
        try{
            if(!file.isOpen) return;
            file.flush();
        }catch(Exception e) {}
    }
    void close() {
        if(file.isOpen) file.close();
    }
    void log(string str) nothrow {
        doLog(str);
    }
    void log(A...)(string fmt, A args) nothrow {
        try{
            doLog(format(fmt, args));
        }catch(Exception e) {}
    }
    private:
    string filename;
    File file;

    void doLog(string str) nothrow {
        try{
            if(!file.isOpen) {
                file.open(filename, "w");
            }
            auto dt = Clock.currTime();
            string dateTime = "[%02u:%02u:%02u.%03u] "
            .format(dt.hour, dt.minute, dt.second, dt.fracSecs.total!("msecs"));

            file.write(dateTime);
            file.write(str);
            file.write("\n");
        }catch(Exception e) {}
    }
}
