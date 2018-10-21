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
        this.contents = convertTabsToSpaces(cast(string)read(module_.getPath()));
        log("Parser: Reading %s -> %s bytes", module_.getPath(), contents.length);
        watch.stop();
    }
    void tokenise() {
        auto tokens = getImplicitImportsTokens() ~ lexer.tokenise(contents);
        log("... found %s tokens", tokens.length);
        lexer.dumpTokens(tokens);

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
            throw new CompilerError(fns[1], "Multiple module 'new' functions are not allowed");
        }
        bool hasModuleInit = fns.length==1;
        bool isMainModule  = module_.isMainModule;

        /// Add a module new() function if it does not exist
        Function initFunc;
        if(hasModuleInit) {
            initFunc = fns[0];
        } else {
            /// No module init function exists
            initFunc = makeNode!Function;
            initFunc.name       = "new";
            initFunc.moduleName = module_.canonicalName;
            module_.add(initFunc);

            auto params = makeNode!Parameters;
            auto type   = makeNode!FunctionType;
            type.params = params;
            auto lit    = makeNode!LiteralFunction;
            lit.add(params);
            lit.type = type;
            initFunc.add(lit);
        }

        if(isMainModule) {
            /// Check for a program entry point
            auto mainfns = module_.getFunctions("main");
            if(mainfns.length > 1) {
                throw new CompilerError(mainfns[1], "Multiple program entry points found");
            } else if(mainfns.length==0) {
                throw new CompilerError(module_, "No program entry point found");
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
        log("Parser: %s Extracting exports", module_.canonicalName);
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
                } else if(t.isKeyword("alias")) {
                    t.next;
                    module_.exportedTypes.add(t.value);
                } else if(t.isKeyword("extern")) {
                    t.next;
                    module_.exportedFunctions.add(t.value);
                } else if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.LCURLY) {
                    module_.exportedFunctions.add(t.value);
                } else if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.LANGLE) {
                    int end;
                    if(isTemplateParams(t, 1, end) && t.peek(end+1).type==TT.LCURLY) {
                        module_.exportedFunctions.add(t.value);
                    }
                }
            }
            t.next;
        }
        watch.stop();
    }
    Token[] getImplicitImportsTokens() {
        auto tokens = appender!(Token[]);

        Token tok(string value) {
            Token t;
            t.type   = TT.IDENTIFIER;
            t.line   = 1;
            t.column = 1;
            t.value  = value;
            return t;
        }

        __gshared static string[] IMPORTS = [
            "core::core",
            "core::c",
            "core::hooks",
            "core::list",
            "core::string",
            "core::console",
            "core::unsigned",
        ];

        foreach(s; IMPORTS) {
            if(module_.canonicalName!=s) {
                tokens ~= tok("import");
                tokens ~= tok(s);
            }
        }

        return tokens.data;
    }
}