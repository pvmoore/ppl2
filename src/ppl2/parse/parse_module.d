module ppl2.parse.parse_module;

import ppl2.internal;
///
/// 1) Read file contents
/// 2) Tokenise
/// 3) Parse statements
///
final class ModuleParser {
private:
    Module module_;
    StopWatch watch;
    Lexer lexer;
    TokenNavigator nav;
    string contents;
    Token[] tokens;

    StatementParser stmtParser() { return module_.stmtParser; }
public:
    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    this(Module module_) {
        this.module_    = module_;
        this.lexer      = new Lexer(module_);
    }
    void readContents() {
        watch.start();
        import std.file : read;
        this.contents = cast(string)read(module_.getPath());
        log("Parser: Reading %s -> %s bytes", module_.getPath(), contents.length);
        watch.stop();
    }
    void tokenise() {
        this.tokens = lexer.tokenise(contents);
        this.nav    = new TokenNavigator(module_, tokens);
    }
    ///
    /// Look for exports statement and read all export names.
    /// For each, find out whether it is a type or a function.
    ///
    void extractExports() {
        watch.start();
        log("Parser: Extracting exports");
        doExtractExports();
        watch.stop();
    }
    ///
    /// Tokenise the contents and then start to parse the statements.
    /// Continue parsing until an import statement is found
    /// where the exports are not yet known.
    ///
    void parse() {
        watch.start();
        log("[%s] Parsing from line %s", module_.canonicalName, nav.line);

        while(nav.hasNext()) {
            auto cont = stmtParser().parse(nav, module_);
            if(!cont) {
                log("[%s] Parser pausing at line %s", module_.canonicalName, nav.line);
                break;
            }
        }

        if(!nav.hasNext()) {
            log("[%s] Parser finished", module_.canonicalName);
            moduleFullyParsed();
            module_.isParsed = true;
        }

        watch.stop();
    }
private:
    ///
    ///  1) Check that there is only 1 module init function.
    ///  2) Create one if there are none.
    ///  3) Make main module init function live.
    ///  4) Check that we have a program entry point and set it live
    ///  5) Request resolution of the module "new" method
    ///
    void moduleFullyParsed() {
        auto fns = module_.getFunctions("new");
        if(fns.length>1) {
            throw new CompilerError(Err.MULTIPLE_MODULE_INITS, fns[1],
                "Multiple module 'new' functions are not allowed");
        }
        bool hasModuleInit = fns.length==1;
        bool isMainModule  = module_.canonicalName==g_mainModuleCanonicalName;

        Function initFunc;
        if(hasModuleInit) {
            initFunc = fns[0];
        } else {
            /// No module init function exists
            initFunc = makeNode!Function;
            initFunc.name       = "new";
            initFunc.moduleName = module_.canonicalName;
            module_.addToEnd(initFunc);

            auto args = makeNode!Arguments;
            auto type = makeNode!FunctionType;
            type.args = args;
            auto lit  = makeNode!LiteralFunction;
            lit.addToEnd(args);
            lit.type = type;
            initFunc.addToEnd(lit);
        }
        if(isMainModule) {
            g_mainModuleNID = module_.nid;

            auto mainfns = module_.getFunctions("main");
            if(mainfns.length > 1) {
                throw new CompilerError(Err.MULTIPLE_ENTRY_POINTS, mainfns[1],
                    "Multiple program entry points found");
            } else if(mainfns.length==0) {
                throw new CompilerError(Err.NO_PROGRAM_ENTRY_POINT, module_,
                    "No program entry point found");
            }

            /// Add an external ref to the entry function
            mainfns[0].numRefs++;
            module_.numRefs++;
        }

        /// Request init function resolution
        functionRequired(module_.canonicalName, "new");
    }
    void doExtractExports() {
        auto exportKw = new Set!string;
        auto names    = new Set!string;
        auto indexes  = new Set!int;
        auto t        = new TokenNavigator(module_, tokens);

        exportKw.add("export");

        /// Find all the exports
        while(t.hasNext) {
            auto i = t.findInScope(exportKw);
            if(i==-1) break;

            t.next(i+1);

            indexes.add(t.index);
            names.add(t.value);
            t.next;

            while(t.type==TT.COMMA) {
                t.next;
                indexes.add(t.index);
                names.add(t.value);
                t.next;
            }
        }

        //dd("   exports", names.values);
        //dd("   indexes", indexes.values);

        if(names.length==0) return;

        /// Now find out whether they are types or functions
        t.reset();
        int numFound = 0;

        while(t.hasNext) {
            auto i = t.findInScope(names);
            if(i==-1) {
                throw new CompilerError(Err.EXPORT_NOT_FOUND, module_, "Export %s not found".format(names.values));
            }
            t.next(i);

            if(!indexes.contains(t.index)) {
                auto name = t.value;

                if(t.peek(-1).value=="define") {
                    module_.exportedTypes ~= name;
                } else if(t.peek(1).type==TT.EQUALS && t.peek(2).type==TT.LSQBRACKET) {
                    module_.exportedTypes ~= name;
                } else {
                    module_.exportedFunctions ~= name;
                }

                if(++numFound==names.length) return;
            }

            t.next;
        }
    }
}