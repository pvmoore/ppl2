module ppl2.parse.parse_module;

import ppl2.internal;
///
/// 1) Read file contents
/// 2) Tokenise
/// 3) Extract exports
/// 4) Parse statements
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
    /// Look for exported functions, defines and structs
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
    ///  - Check that there is only 1 module init function.
    ///  - Create one if there are none.
    ///  - Check that we have a program entry point
    ///  - Request resolution of the module "new" method
    ///
    void moduleFullyParsed() {
        /// Ensure no more than one module new() function exists
        auto fns = module_.getFunctions("new");
        if(fns.length>1) {
            throw new CompilerError(Err.MULTIPLE_MODULE_INITS, fns[1],
                "Multiple module 'new' functions are not allowed");
        }
        bool hasModuleInit = fns.length==1;
        bool isMainModule  = module_.canonicalName==g_mainModuleCanonicalName;

        /// Add a module new() function if it does not exist
        Function initFunc;
        if(hasModuleInit) {
            initFunc = fns[0];
        } else {
            /// No module init function exists
            initFunc = makeNode!Function;
            initFunc.name       = "new";
            initFunc.moduleName = module_.canonicalName;
            module_.addToEnd(initFunc);

            auto params = makeNode!Parameters;
            auto type   = makeNode!FunctionType;
            type.params = params;
            auto lit    = makeNode!LiteralFunction;
            lit.addToEnd(params);
            lit.type = type;
            initFunc.addToEnd(lit);
        }
        if(isMainModule) {
            g_mainModuleNID = module_.nid;

            /// Check for a program entry point
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
        auto t = new TokenNavigator(module_, tokens);

        bool public_ = false;

        while(t.hasNext) {
            if(t.isKeyword("public")) {
                public_ = true;
            } else if(t.isKeyword("private")) {
                public_ = false;
            } else if(t.type==TT.LCURLY) {
                t.next(t.findEndOfBlock(t.type));
            } else if(t.type==TT.LSQBRACKET) {
                t.next(t.findEndOfBlock(t.type));
            } else if(public_) {

                if(t.isKeyword("struct")) {
                    t.next;
                    module_.exportedTypes ~= t.value;
                } else if(t.isKeyword("define")) {
                    t.next;
                    module_.exportedTypes ~= t.value;
                } else if(t.isKeyword("extern")) {
                    t.next;
                    module_.exportedFunctions ~= t.value;
                }else if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.EQUALS && t.peek(2).type==TT.LCURLY) {
                    module_.exportedFunctions ~= t.value;
                }
            }
            t.next;
        }

    }
}