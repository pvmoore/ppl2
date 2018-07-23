module ppl2.ast.module_;

import ppl2.internal;

final class Module : ASTNode, Scope, Container {
private:
    int tempCounter;
public:
    string canonicalName;
    int numRefs;
    string[] exportedTypes;     /// name of each exported types
    string[] exportedFunctions; /// name of each exported functions
    bool isParsed;
    Set!ASTNode activeRoots;  /// Active root nodes

    LiteralString[][string] literalStrings;
    Closure[] closures;

    ModuleParser parser;
    ModuleResolver resolver;
    ModuleChecker checker;
    ModuleConstantFolder constFolder;
    OptimisationDCE dce;
    ModuleGenerator gen;
    Templates templates;

    StatementParser stmtParser;
    ExpressionParser exprParser;
    TypeParser typeParser;
    TypeDetector typeDetector;
    NamedStructParser namedStructParser;
    VariableParser varParser;
    NodeBuilder nodeBuilder;

    LLVMModule llvmValue;
    LiteralString moduleNameLiteral;

    this(string canonicalName, LLVMWrapper llvm) {
        this.nid           = g_nodeid++;
        this.canonicalName = canonicalName;

        log("Creating new Module(%s)", canonicalName);

        parser            = new ModuleParser(this);
        resolver          = new ModuleResolver(this);
        checker           = new ModuleChecker(this);
        constFolder       = new ModuleConstantFolder(this);
        dce               = new OptimisationDCE(this);
        gen               = new ModuleGenerator(this, llvm);
        templates         = new Templates(this);

        stmtParser        = new StatementParser(this);
        exprParser        = new ExpressionParser(this);
        typeParser        = new TypeParser(this);
        typeDetector      = new TypeDetector(this);
        namedStructParser = new NamedStructParser(this);
        varParser         = new VariableParser(this);
        nodeBuilder       = new NodeBuilder(this);
        activeRoots       = new Set!ASTNode;

        moduleNameLiteral = makeNode!LiteralString;
        moduleNameLiteral.value = canonicalName;
        addLiteralString(moduleNameLiteral);
    }

    void addLiteralString(LiteralString s) {
        literalStrings[s.value] ~= s;
    }
    void addClosure(Closure c) {
        closures ~= c;
    }
    void addActiveRoot(ASTNode node) {
        activeRoots.add(node.getRoot);
    }

    NodeBuilder builder(ASTNode n) { return nodeBuilder.forNode(n); }

    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.MODULE; }

    string getPath() {
        return getFullPath(canonicalName);
    }
    bool isMainModule() {
        return nid==g_mainModuleNID;
    }
    string makeTemporary(string prefix) {
        return "__%s%s".format(prefix, tempCounter++);
    }
    ///
    /// Return the module init function.
    ///
    Function getInitFunction() {
        return getFunctions("new")[0];
    }
    ///
    /// Find a define at the module scope.
    ///
    Define getDefine(string name) {
        foreach(c; children) {
            if(!c.isDefine) continue;
            auto def = c.as!Define;
            if(def.name==name) return def;
        }
        return null;
    }
    Define[] getDefines() {
        return children[].filter!(it=>it.isDefine).array.to!(Define[]);
    }
    NamedStruct getNamedStruct(string name) {
        foreach(c; children) {
            if(!c.isNamedStruct) continue;
            auto ns = c.as!NamedStruct;
            if(ns.name==name) return ns;
        }
        return null;
    }
    NamedStruct[] getAllNamedStructs() {
        auto array = new Array!NamedStruct;
        selectDescendents!NamedStruct(array);
        return array[];
    }
    ///
    /// Find all functions with given name at module scope.
    ///
    Function[] getFunctions(string name) {
        Function[] array;
        foreach(c; children) {
            if(c.id()!=NodeID.FUNCTION) continue;
            auto f = cast(Function)c;
            if(f.name==name) array ~= f;
        }
        return array;
    }
    ///
    /// Find all functions at module scope.
    ///
    Function[] getFunctions() {
        Function[] array;
        foreach(c; children) {
            if(c.id()!=NodeID.FUNCTION) continue;
            array ~= c.as!Function;
        }
        return array;
    }
    ///
    /// Find all Variables at module scope.
    ///
    Variable[] getVariables() {
        return cast(Variable[])children[].filter!(it=>it.id()==NodeID.VARIABLE).array;
    }
    ///
    /// Find all AnonStructs at module scope.
    ///
    Type[] getAnonStructs() {
        auto array = new Array!ASTNode;
        recursiveCollect(array,
            it => it.getType.isAnonStruct
        );
        return cast(Type[])array[].map!(it=>it.getType).array;
    }
    //================================================================================
    NamedStruct[] getImportedNamedStructs() {
        NamedStruct[string] structs;
        /// Collect Identifiers with external targets
        auto array = new Array!ASTNode;
        recursiveCollect(array, it=>
            it.id()==NodeID.IDENTIFIER &&
            it.as!Identifier.target.isVariable() &&
            it.as!Identifier.target.targetModule.nid != nid
        );
        foreach(id; array[].as!(Identifier[])) {
            auto var     = id.target.getVariable();
            auto struct_ = var.type.getNamedStruct;
            if(struct_) {
                structs[struct_.getUniqueName] = struct_;
            }
        }
        array.clear();

        /// Collect struct Variables
        recursiveCollect(array, it=>
            it.id()==NodeID.VARIABLE &&
            it.as!Variable.type.isNamedStruct
        );
        foreach(v; array) {
            auto ns = v.as!Variable.type.getNamedStruct;
            if(ns.getModule.nid != nid) structs[ns.getUniqueName] = ns;
        }

        /// Collect structs from arguments of imported functions
        auto types = new Array!Type;
        foreach(f; getImportedFunctions()) {
            types.clear();
            f.getType.getChildTypes(types);
            foreach(t; types) {
                auto struct_ = t.getNamedStruct;
                if(struct_) {
                    structs[struct_.getUniqueName] = struct_;
                }
            }
        }
        return structs.values;
    }
    Function[] getImportedFunctions() {
        auto array = new Array!ASTNode;
        recursiveCollect(array,
            it=> it.id()==NodeID.CALL &&
                 it.as!Call.target.isFunction() &&
                 it.as!Call.target.targetModule.nid != nid
        );
        /// De-dup
        auto set = new Set!Function;
        foreach(call; array) {
            set.add(call.as!Call.target.getFunction());
        }
        return set.values;
    }
    Function[] getExternalFunctions() {
        return getFunctions().filter!(it=>it.isExtern).array;
    }
    ///
    ///  Dump module info to the log.
    ///
    //void dumpInfo() {
    //    writefln("\tExported types ............ %s", exportedTypes);
    //    writefln("\tExported functions ........ %s", exportedFunctions);
    //
    //    writefln("\tLocal anon structs ........ %s", getAnonStructs());
    //    writefln("\tLocal named structs ....... %s", getAllNamedStructs().map!(it=>it.name));
    //    writefln("\tImported named structs .... %s", getImportedNamedStructs().map!(it=>it.name));
    //
    //    writefln("\tLocal functions ........... %s", getFunctions().map!(it=>it.getUniqueName));
    //    writefln("\tImported functions ........ %s", getImportedFunctions.map!(it=>it.getUniqueName));
    //    writefln("\tExternal functions ........ %s", getExternalFunctions().map!(it=>it.getUniqueName));
    //}

    override string toString() const {
        return "Module[refs=%s] %s".format(numRefs, canonicalName);
    }
    //==============================================================================
    static string getCanonicalName(string path) {
        /// Assumes path is normalised
        import std.array;
        import std.path;

        auto rel = path[getConfig().basePath.length..$];
        return rel.stripExtension.replace("/", ".").replace("\\", ".");
    }
    ///
    /// Return the full path including the module filename and extension
    ///
    static string getFullPath(string canonicalName) {
        import std.array;
        return getConfig().basePath ~ canonicalName.replace(".", "/") ~ ".p2";
    }
}