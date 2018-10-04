module ppl2.ast.module_;

import ppl2.internal;
import std.array : replace;

final class Module : ASTNode, Container {
private:
    int tempCounter;
public:
    string canonicalName;
    string fileName;
    int numRefs;
    Set!string exportedTypes;     /// name of each exported types
    Set!string exportedFunctions; /// name of each exported functions
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
        this.nid               = g_nodeid++;
        this.canonicalName     = canonicalName;
        this.exportedTypes     = new Set!string;
        this.exportedFunctions = new Set!string;
        this.fileName          = canonicalName.replace("::", ".");

        addUniqueName(canonicalName);
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
    void removeClosure(Closure c) {
        import common : remove;
        closures.remove(c);
    }
    void addActiveRoot(ASTNode node) {
        activeRoots.add(node.getRoot);
    }

    NodeBuilder builder(ASTNode n) {
        return nodeBuilder.forNode(n);
    }

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
    /// Find an Alias at the module scope.
    ///
    Alias getAlias(string name) {
        return getAliases()
            .filter!(it=>it.name==name)
            .frontOrNull!Alias;
    }
    Alias[] getAliases() {
        return children[]
            .filter!(it=>it.isAlias)
            .map!(it=>cast(Alias)it)
            .array;
    }
    NamedStruct getNamedStruct(string name) {
        return children[]
            .filter!(it=>it.id==NodeID.NAMED_STRUCT)
            .map!(it=>cast(NamedStruct)it)
            .filter!(it=>it.name==name)
            .frontOrNull!NamedStruct;
    }
    NamedStruct[] getNamedStructsRecurse() {
        auto array = new Array!NamedStruct;
        selectDescendents!NamedStruct(array);
        return array[];
    }
    ///
    /// Find all functions with given name at module scope.
    ///
    Function[] getFunctions(string name) {
        return getFunctions()
            .filter!(it=>it.name==name)
            .array;
    }
    ///
    /// Find all functions at module scope.
    ///
    Function[] getFunctions() {
        return children[]
            .filter!(it=>it.id()==NodeID.FUNCTION)
            .map!(it=>cast(Function)it)
            .array;
    }
    ///
    /// Find all Variables at module scope.
    ///
    Variable[] getVariables() {
        return children[]
            .filter!(it=>it.id()==NodeID.VARIABLE)
            .map!(it=>cast(Variable)it)
            .array;
    }
    ///
    /// Return true if there are Composites at root level which signifies
    /// that a template function has just been added
    ///
    bool containsComposites() {
        foreach(ch; children) {
            if(ch.isComposite) return true;
        }
        return false;
    }
    //================================================================================
    NamedStruct[] getImportedNamedStructs() {
        NamedStruct[string] structs;

        recurse((ASTNode it) {
            auto ns = it.getType.getNamedStruct;
            if(ns && ns.getModule.nid!=nid) {
                structs[ns.getUniqueName] = ns;
            }
        });

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
    ///
    /// Find and return all variables defined in other modules.
    /// These should all be non-private statics.
    ///
    Variable[] getImportedStaticVariables() {
        auto array = new Array!ASTNode;
        recursiveCollect(array, it=>
            it.id()==NodeID.IDENTIFIER &&
            it.as!Identifier.target.isVariable() &&
            it.as!Identifier.target.targetModule.nid != nid &&
            it.as!Identifier.target.getVariable().isStatic
        );
        /// De-dup
        auto set = new Set!Variable;
        foreach(v; array) {
            set.add(v.as!Identifier.target.getVariable());
        }
        return set.values;
    }
    Function[] getInnerFunctions() {
        auto array = new Array!Function;
        recursiveCollect!Function(array, f=>f.isInner);
        return array[];
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
        return getConfig().basePath ~ canonicalName.replace("::", "/") ~ ".p2";
    }
    static void addUniqueName(string canonicalName) {
        string name = canonicalName;
        auto i = canonicalName.lastIndexOf("::");
        if(i!=-1) name = canonicalName[i+2..$];
        g_uniqueStructAndModuleNames.add(name);
    }
}