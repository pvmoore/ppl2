module bench;

import core.memory : GC;
import std.stdio : writefln;
import std.datetime.stopwatch : StopWatch, benchmark;
import std.file : read;
import ppl2;

void main() {
    writefln("Benchmarking ...");

    benchLexer();

    writefln("Finished");
}
void benchLexer() {
    writefln("Lexer ...");

    Lexer lexer = new Lexer(null);
    string text = convertTabsToSpaces(cast(string)read("test/test.p2"));

    const COUNT = 10_000;

    auto results = benchmark!({

        Token[] tokens = lexer.tokenise(text);

    })(COUNT);
    writefln("%.2f millis", results[0].total!"nsecs"/1_000_000.0);

    // 550 ms
}