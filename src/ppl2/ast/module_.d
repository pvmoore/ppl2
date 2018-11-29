module ppl2.ast.module_;

import ppl2.internal;
import std.array : replace;

final class Module : ASTNode, Container {
private:
    int tempCounter;
    Closure[] closures;
    LiteralString[][string] literalStrings;
    Set!ASTNode activeRoots;  /// Active root nodes
public:
    string canonicalName;
    string fileName;
    string fullPath;
    bool isMainModule;        /// true if this module contains the 'main' function

    int numRefs;

    Config config;
    BuildState buildState;
    ModuleParser parser;

    ModuleResolver resolver;
    ModuleChecker checker;
    DeadCodeEliminator dce;
    ModuleGenerator gen;
    Templates templates;
    StatementParser stmtParser;
    ExpressionParser exprParser;
    TypeParser typeParser;
    TypeDetector typeDetector;
    NamedStructParser namedStructParser;
    VariableParser varParser;
    NodeBuilder nodeBuilder;
    TypeFinder typeFinder;

    /// Generation properties
    LLVMModule llvmValue;
    LiteralString moduleNameLiteral;

    this(string canonicalName, LLVMWrapper llvmWrapper, BuildState buildState) {
        this.nid               = g_nodeid++;
        this.canonicalName     = canonicalName;
        this.buildState        = buildState;
        this.config            = buildState.config;
        this.fileName          = canonicalName.replace("::", ".");
        this.fullPath          = config.getFullModulePath(canonicalName);

        log("Creating new Module(%s)", canonicalName);

        parser            = new ModuleParser(this);
        resolver          = new ModuleResolver(this);
        checker           = new ModuleChecker(this);
        dce               = new DeadCodeEliminator(this);
        gen               = new ModuleGenerator(this, llvmWrapper);
        templates         = new Templates(this);
        activeRoots       = new Set!ASTNode;

        stmtParser        = new StatementParser(this);
        exprParser        = new ExpressionParser(this);
        typeParser        = new TypeParser(this);
        typeDetector      = new TypeDetector(this);
        namedStructParser = new NamedStructParser(this);
        varParser         = new VariableParser(this);
        nodeBuilder       = new NodeBuilder(this);
        typeFinder        = new TypeFinder(this);

        moduleNameLiteral = makeNode!LiteralString;
        moduleNameLiteral.value = canonicalName;
        addLiteralString(moduleNameLiteral);
    }
    void clearState() {
        closures = null;
        literalStrings.clear();
        activeRoots.clear();
        children.clear();
        numRefs = 0;
        tempCounter = 0;

        parser.clearState();
        resolver.clearState();
        checker.clearState();
        dce.clearState();
        gen.clearState();
        templates.clearState();
        llvmValue = null;

        addLiteralString(moduleNameLiteral);
    }
/// ASTNode
    override bool isResolved()  { return true; }
    override NodeID id() const  { return NodeID.MODULE; }
    override Module getModule() { return this; }
///

    bool isParsed() { return parser.isParsed; }

    auto getLiteralStrings()               { return literalStrings.values; }
    void addLiteralString(LiteralString s) { literalStrings[s.value] ~= s; }

    Closure[] getClosures()       { return closures; }
    void addClosure(Closure c)    { closures ~= c; }
    void removeClosure(Closure c) { import common : remove; closures.remove(c); }

    auto getCopyOfActiveRoots()      { return activeRoots.values.dup; }
    void addActiveRoot(ASTNode node) { activeRoots.add(node.getRoot); }

    NodeBuilder builder(ASTNode n) {
        return nodeBuilder.forNode(n);
    }

    void addError(ASTNode node, string msg, bool canContinue) {
        buildState.addError(new ParseError(this, node, msg), canContinue);
    }
    void addError(Tokens t, string msg, bool canContinue) {
        buildState.addError(new ParseError(this, t, msg), canContinue);
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
    Enum getEnum(string name) {
        return children[]
            .filter!(it=>it.id==NodeID.ENUM)
            .map!(it=>cast(Enum)it)
            .filter!(it=>it.name==name)
            .frontOrNull!Enum;
    }
    Enum[] getEnumsRecurse() {
        auto array = new Array!Enum;
        selectDescendents!Enum(array);
        return array[];
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
                structs[ns.name] = ns;
            }
        });

        return structs.values;
    }
    Enum[] getImportedEnums() {
        Enum[string] enums;

        recurse((ASTNode it) {
            auto e = it.getType.getEnum;
            if(e && e.getModule.nid!=nid) {
                enums[e.name] = e;
            }
        });

        return enums.values;
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
    /// Return a list of all modules referenced from this module
    ///
    Module[] getReferencedModules() {
        auto m = new Set!Module;
        foreach(ns; getImportedNamedStructs()) {
            m.add(ns.getModule);
        }
        foreach(e; getImportedEnums()) {
            m.add(e.getModule);
        }
        foreach(v; getImportedStaticVariables()) {
            m.add(v.getModule);
        }
        foreach(f; getImportedFunctions()) {
            m.add(f.getModule);
        }
        m.remove(this);
        return m.values;
    }

    ///
    ///  Dump module info to the log.
    ///
    //void dumpInfo() {
    //    writefln("\tExported types ............ %s", exportedTypes);
    //    writefln("\tExported functions ........ %s", exportedFunctions);
    //
    //    writefln("\tLocal tuples .............. %s", getTuples());
    //    writefln("\tLocal named structs ....... %s", getAllNamedStructs().map!(it=>it.name));
    //    writefln("\tImported named structs .... %s", getImportedNamedStructs().map!(it=>it.name));
    //
    //    writefln("\tLocal functions ........... %s", getFunctions().map!(it=>it.getUniqueName));
    //    writefln("\tImported functions ........ %s", getImportedFunctions.map!(it=>it.getUniqueName));
    //    writefln("\tExternal functions ........ %s", getExternalFunctions().map!(it=>it.getUniqueName));
    //}

    override int opCmp(Object o) const {
        import std.algorithm.comparison;
        Module other = cast(Module)o;
        return nid==other.nid ? 0 :
               cmp(canonicalName, other.canonicalName);
    }
    override string toString() const {
        return "Module[refs=%s] %s".format(numRefs, canonicalName);
    }
}