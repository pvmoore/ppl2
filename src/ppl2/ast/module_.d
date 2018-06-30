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
    LiteralFunction[] literalFunctions;

    ModuleParser parser;
    ModuleResolver resolver;
    ModuleChecker checker;
    ModuleConstantFolder constFolder;
    OptimisationDCE dce;
    ModuleGenerator gen;

    StatementParser stmtParser;
    ExpressionParser exprParser;
    TypeParser typeParser;
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

        stmtParser        = new StatementParser(this);
        exprParser        = new ExpressionParser(this);
        typeParser        = new TypeParser(this);
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
    void addLiteralFunction(LiteralFunction f) {
        literalFunctions ~= f;
    }

    NodeBuilder builder(ASTNode n) { return nodeBuilder.forNode(n); }

    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.MODULE; }

    bool isMainModule() {
        return nid==g_mainModuleNID;
    }
    string getPath() const {
        import std.array;
        return getConfig().basePath ~ canonicalName.replace(".", "/") ~ ".p2";
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
    NamedStruct[] getNamedStructs() {
        return children[].filter!(it=>it.isNamedStruct).array.to!(NamedStruct[]);
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
    Type[] getAnonStructs() {
        auto array = new Array!ASTNode;
        recursiveCollect(array,
            it => it.getType.isAnonStruct
        );
        return cast(Type[])array[].map!(it=>it.getType).array;
    }
    Function[] getLocalFunctions() {
        auto array = new Array!ASTNode;
        recursiveCollect(array,
            it=> it.id()==NodeID.FUNCTION &&
                 it.as!Function.isGlobal
        );
        return cast(Function[])array[];
    }
    Function[] getImportedFunctions() {
        auto array = new Array!ASTNode;
        recursiveCollect(array,
            it=> it.id()==NodeID.CALL &&
                 it.as!Call.target.isFunction() &&
                 it.as!Call.target.getFunction().moduleName != canonicalName
        );
        return cast(Function[])array[].map!(it=>it.as!Call.target.getFunction()).array;
    }
    Function[] getExternalFunctions() {
        return getFunctions().filter!(it=>it.isExtern).array;
    }
    ///
    ///  Dump module info to the log.
    ///
    void dumpInfo() {
        writefln("\tExported types ............ %s", exportedTypes);
        writefln("\tExported functions ........ %s", exportedFunctions);
        writefln("\tLocal anon structs ........ %s", getAnonStructs());
        writefln("\tLocal named structs ....... %s", getNamedStructs().map!(it=>it.name));

        //writefln("\tLocal defines ............. %s", getLocalDefines.map!(it=>it.name));
        //writefln("\tImported defines .......... %s", getImportedDefines().map!(it=>it.name));
        writefln("\tLocal functions ........... %s", getLocalFunctions().map!(it=>it.getUniqueName));
        writefln("\tImported functions ........ %s", getImportedFunctions.map!(it=>it.getUniqueName));
        writefln("\tExternal functions ........ %s", getExternalFunctions().map!(it=>it.getUniqueName));
    }

    override string toString() const {
        return "Module[refs=%s] %s".format(numRefs, canonicalName);
    }
    //==============================================================================
    // Assumes path is normalised
    static string getCanonicalName(string path) {
        import std.array;
        import std.path;

        auto rel = path[getConfig().basePath.length..$];
        return rel.stripExtension.replace("/", ".").replace("\\", ".");
    }
}