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
    Tokens[] navs;
    ASTNode[] startNodes;
    string contents;

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
        auto tokens      = lexer.tokenise(contents);
        this.navs       ~= new Tokens(module_, tokens);
        this.startNodes ~= module_;
        extractExports(tokens);
    }
    void appendTokens(ASTNode afterNode, Token[] tokens) {
        auto t = new Tokens(module_, tokens);
        this.navs ~= t;
        if(afterNode.isFunction) {
            t.setAccess(afterNode.as!Function.access);
        } else {
            assert(afterNode.isNamedStruct);
            t.setAccess(afterNode.as!NamedStruct.access);
        }

        auto composite = Composite.make(navs[$-1], Composite.Usage.PLACEHOLDER);
        afterNode.parent.insertAt(afterNode.index, composite);
        this.startNodes ~= composite;
        module_.isParsed = false;
        module_.addActiveRoot(composite);
    }
    ///
    /// Tokenise the contents and then start to parse the statements.
    /// Continue parsing until an import statement is found
    /// where the exports are not yet known.
    ///
    void parse() {
        watch.start();

        log("[%s] Parsing", module_.canonicalName);

        foreach(i, nav; navs) {
            while(nav.hasNext()) {
                stmtParser().parse(nav, startNodes[i]);
            }
        }

        log("[%s] Parsing finished", module_.canonicalName);
        moduleFullyParsed();
        module_.isParsed = true;

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
    ///
    /// Look for exported functions, defines and structs
    ///
    void extractExports(Token[] tokens) {
        watch.start();
        log("Parser: Extracting exports");
        auto t = new Tokens(module_, tokens);

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
                    module_.exportedTypes.add(t.value);
                } else if(t.isKeyword("define")) {
                    t.next;
                    module_.exportedTypes.add(t.value);
                } else if(t.isKeyword("extern")) {
                    t.next;
                    module_.exportedFunctions.add(t.value);
                } else if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.EQUALS && t.peek(2).type==TT.LCURLY) {
                    module_.exportedFunctions.add(t.value);
                } else if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.EQUALS && t.peek(2).type==TT.LANGLE) {
                    module_.exportedFunctions.add(t.value);
                }
            }
            t.next;
        }
        watch.stop();
    }
}