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

    Tokens mainTokens;
    Tokens[] templateTokens;
    ASTNode[] templateStartNodes;
    bool mainParseComplete;
    bool templateParseComplete;

    string sourceText;
    Hash!20 sourceTextHash;
public:
    Set!string publicTypes;
    Set!string privateFunctions;
    Set!string publicFunctions;

    ulong getElapsedNanos()   { return watch.peek().total!"nsecs"; }
    Tokens getInitialTokens() { return mainTokens; }
    auto getSourceTextHash()  { return sourceTextHash; }
    bool isParsed()           { return mainParseComplete && templateParseComplete; }

    this(Module module_) {
        this.module_          = module_;
        this.lexer            = new Lexer(module_);
        this.publicTypes      = new Set!string;
        this.privateFunctions = new Set!string;
        this.publicFunctions  = new Set!string;
    }
    void clearState() {
        publicFunctions.clear();
        privateFunctions.clear();
        publicTypes.clear();
        mainParseComplete = false;
        templateParseComplete = false;
        templateTokens = null;
        templateStartNodes = null;
        module_.children.clear();
        sourceText = null;
        sourceTextHash.invalidate();
        watch.reset();
    }
    ///
    /// Set/reset the source text.
    ///
    void setSourceText(string src) {
        assert(false==From!"common".contains(src, "\t"));

        this.sourceTextHash = Hasher.sha1(src);
        this.sourceText     = src;
        log("Parser: %s src -> %s bytes hash:%s", module_.fullPath, sourceText.length, sourceTextHash);

        tokenise();
        collectTypesAndFunctions();
    }
    void readSourceFromDisk() {
        import std.file : read;
        setSourceText(convertTabsToSpaces(cast(string)read(module_.fullPath)));
    }
    ///
    /// Tokenise the contents and then start to parse the statements.
    /// Continue parsing until an import statement is found
    /// where the exports are not yet known.
    ///
    void parse() {
        if(isParsed()) return;
        watch.start();

        log("[%s] Parsing", module_.canonicalName);

        /// Parse all module tokens
        while(mainTokens.hasNext) {
            module_.stmtParser.parse(mainTokens, module_);
        }
        /// Parse subsequently added template tokens
        foreach(i, nav; templateTokens) {
            while(nav.hasNext()) {
                module_.stmtParser.parse(nav, templateStartNodes[i]);
            }
        }

        log("[%s] Parsing finished", module_.canonicalName);
        moduleFullyParsed();

        mainParseComplete     = true;
        templateParseComplete = true;
        watch.stop();
    }
    void appendTokensFromTemplate(ASTNode afterNode, Token[] tokens) {
        auto t = new Tokens(module_, tokens);
        this.templateTokens ~= t;
        if(afterNode.isFunction) {
            t.setAccess(afterNode.as!Function.access);
        } else {
            assert(afterNode.id==NodeID.NAMED_STRUCT);
            t.setAccess(afterNode.as!NamedStruct.access);
        }

        auto composite = Composite.make(t, Composite.Usage.PLACEHOLDER);
        afterNode.parent.insertAt(afterNode.index, composite);
        this.templateStartNodes ~= composite;
        templateParseComplete = false;
        module_.addActiveRoot(composite);
    }
private:
    void tokenise() {
        watch.start();
        auto tokens = getImplicitImportsTokens() ~ lexer.tokenise(sourceText, module_.buildState);
        log("... found %s tokens", tokens.length);
        lexer.dumpTokens(tokens);

        this.mainTokens = new Tokens(module_, tokens);
        watch.stop();
    }
    ///
    /// Look for module scope functions, aliases and structs
    ///
    void collectTypesAndFunctions() {
        watch.start();
        log("Parser: %s Extracting exports", module_.canonicalName);

        auto t       = mainTokens;
        bool public_ = false;

        bool isStruct() {
            return t.isKeyword("struct");
        }
        bool isAlias() {
            return t.isKeyword("alias");
        }
        /// Assumes isStruct() and isAlias() returned false
        bool isFuncDecl() {
            if(t.isKeyword("extern")) return true;
            if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.LCURLY) return true;
            if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.LANGLE) {
                int end;
                if(isTemplateParams(t, 1, end) && t.peek(end+1).type==TT.LCURLY) return true;
            }
            return false;
        }

        while(t.hasNext) {
            if(t.isKeyword("public")) {
                public_ = true;
            } else if(t.isKeyword("private")) {
                public_ = false;
            } else if(t.isKeyword("readonly")) {
                module_.addError(t, "readonly access is only allowed inside a struct", true);
            } else if(t.type==TT.LCURLY) {
                t.next(t.findEndOfBlock(t.type));
            } else if(t.type==TT.LSQBRACKET) {
                t.next(t.findEndOfBlock(t.type));
            } else if(public_) {

                if(isStruct() || isAlias()) {
                    t.next;
                    //module_.exportedTypes.add(t.value);
                    publicTypes.add(t.value);
                } else if(isFuncDecl()) {
                    if(t.isKeyword("extern")) t.next;
                    publicFunctions.add(t.value);
                }
            } else {
                /// private
                if(!isStruct() && isFuncDecl()) {
                    if(t.isKeyword("extern")) t.next;
                    privateFunctions.add(t.value);
                }
            }
            t.next;
        }
        t.reset();
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
    ///
    ///  - Check that there is only 1 module init function.
    ///  - Create one if there are none.
    ///  - Check that we have a program entry point
    ///  - Request resolution of the module "new" method
    ///
    void moduleFullyParsed() {
        /// Only do this once
        if(mainParseComplete) return;

        /// Ensure no more than one module new() function exists
        auto fns = module_.getFunctions("new");
        if(fns.length>1) {
            module_.addError(fns[1], "Multiple module 'new' functions are not allowed", true);
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
                module_.addError(mainfns[1], "Multiple program entry points found", true);
            } else if(mainfns.length==0) {
                module_.addError(module_, "No program entry point found", true);
            } else {
                /// Add an external ref to the entry function
                mainfns[0].numRefs++;
                module_.numRefs++;
            }
        }

        /// Request init function resolution
        module_.buildState.functionRequired(module_.canonicalName, "new");
    }
}