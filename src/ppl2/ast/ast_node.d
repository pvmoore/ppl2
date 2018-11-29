module ppl2.ast.ast_node;

import ppl2.internal;

//=============================================================================== NodeID
enum NodeID {
    ADDRESS_OF,
    ALIAS,
    ARRAY,
    AS,
    ASSERT,
    BINARY,
    BREAK,
    BUILTIN_FUNC,
    CALL,
    CALLOC,
    CASE,
    CLOSURE,
    COMPOSITE,
    CONSTRUCTOR,
    CONTINUE,
    DOT,
    LITERAL_EXPR_LIST,
    ENUM,
    ENUM_MEMBER,
    ENUM_MEMBER_REF,
    ENUM_MEMBER_VALUE,
    FUNC_TYPE,
    FUNCTION,
    IDENTIFIER,
    IF,
    IMPORT,
    INITIALISER,
    IS,
    INDEX,
    LITERAL_ARRAY,
    LITERAL_FUNCTION,
    LITERAL_MAP,
    LITERAL_NULL,
    LITERAL_NUMBER,
    LITERAL_STRING,
    LITERAL_TUPLE,
    LOOP,
    META_FUNCTION,
    MODULE,
    MODULE_ALIAS,
    NAMED_STRUCT,
    PARAMETERS,
    PARENTHESIS,
    RETURN,
    SELECT,
    STRUCT_CONSTRUCTOR,
    TUPLE,
    TYPE_EXPR,
    UNARY,
    VALUE_OF,
    VARIABLE,
}
//=============================================================================== ASTNode
T makeNode(T)() {
    T n = new T;
    n.nid = g_nodeid++;
    assert(n.children);
    return n;
}
T makeNode(T)(Tokens t) {
    T n      = new T;
    n.nid    = g_nodeid++;
    n.line   = t.line;
    n.column = t.column;
    assert(n.children);
    return n;
}
T makeNode(T)(ASTNode p) {
    T n      = new T;
    n.nid    = g_nodeid++;
    n.line   = p ? p.line   : -1;
    n.column = p ? p.column : -1;
    assert(n.children);
    return n;
}
bool isAs(inout ASTNode n)              { return n.id()==NodeID.AS; }
bool isBinary(inout ASTNode n)          { return n.id()==NodeID.BINARY; }
bool isCall(inout ASTNode n)            { return n.id()==NodeID.CALL; }
bool isCase(inout ASTNode n)            { return n.id()==NodeID.CASE; }
bool isComposite(inout ASTNode n)       { return n.id()==NodeID.COMPOSITE; }
bool isAlias(inout ASTNode n)           { return n.id()==NodeID.ALIAS; }
bool isDot(inout ASTNode n)             { return n.id()==NodeID.DOT; }
bool isExpression(inout ASTNode n)      { return n.as!Expression !is null; }
bool isFunction(inout ASTNode n)        { return n.id()==NodeID.FUNCTION; }
bool isIdentifier(inout ASTNode n)      { return n.id()==NodeID.IDENTIFIER; }
bool isIf(inout ASTNode n)              { return n.id()==NodeID.IF; }
bool isIndex(inout ASTNode n)           { return n.id()==NodeID.INDEX; }
bool isInitialiser(inout ASTNode n)     { return n.id()==NodeID.INITIALISER; }
bool isLiteralNull(inout ASTNode n)     { return n.id()==NodeID.LITERAL_NULL; }
bool isLiteralNumber(inout ASTNode n)   { return n.id()==NodeID.LITERAL_NUMBER; }
bool isLiteralFunction(inout ASTNode n) { return n.id()==NodeID.LITERAL_FUNCTION; }
bool isLoop(inout ASTNode n)            { return n.id()==NodeID.LOOP; }
bool isModule(inout ASTNode n)          { return n.id()==NodeID.MODULE; }
bool isReturn(inout ASTNode n)          { return n.id()==NodeID.RETURN; }
bool isSelect(inout ASTNode n)          { return n.id()==NodeID.SELECT; }
bool isTypeExpr(inout ASTNode n)        { return n.id()==NodeID.TYPE_EXPR; }
bool isVariable(inout ASTNode n)        { return n.id()==NodeID.VARIABLE; }

bool areAll(NodeID ID)(ASTNode[] n) { return n.all!(it=>it.id==ID); }
bool areResolved(ASTNode[] nodes) { return nodes.all!(it=>it.isResolved); }
bool areResolved(Expression[] nodes) { return nodes.all!(it=>it.isResolved); }
bool areResolved(Variable[] nodes) { return nodes.all!(it=>it.isResolved); }

abstract class ASTNode {
private:
    Module module_;
public:
    Array!ASTNode children;
    ASTNode parent;
    int line   = -1;
    int column = -1;
    int nid;

    this() {
        children = new Array!ASTNode;
    }

/// Override these
    abstract NodeID id() const;
    abstract bool isResolved() { return false; }
    Type getType()             { return TYPE_UNKNOWN; }
/// end

    bool hasChildren() const { return children.length > 0; }
    int numChildren() const { return cast(int)children.length; }
    Module getModule() {
        if(!module_) {
            module_ = findModule();
        }
        return module_;
    }
    int getDepth() {
        if(this.id==NodeID.MODULE) return 0;
        return parent.getDepth() + 1;
    }
    ASTNode getParentIgnoreComposite() {
        if(parent.isComposite) return parent.getParentIgnoreComposite();
        return parent;
    }
    bool isAttached() {
        if(this.isModule) return true;
        if(parent is null) return false;
        return parent.isAttached();
    }

    auto addToFront(ASTNode child) {
        child.detach();
        children.insertAt(0, child);
        child.parent = this;
        return this;
    }
    auto add(ASTNode child) {
        child.detach();
        children.add(child);
        child.parent = this;
        return this;
    }

    void insertAt(int index, ASTNode child) {
        child.detach();
        children.insertAt(index, child);
        child.parent = this;
    }
    void remove(ASTNode child) {
        children.remove(child);
        child.parent = null;
    }
    void removeAt(int index) {
        auto child = children.removeAt(index);
        child.parent = null;
    }
    void removeLast() {
        assert(children.length>0);
        auto child = children.removeAt(children.length.as!int-1);
        child.parent = null;
    }
    void replaceChild(ASTNode child, ASTNode otherChild) {
        int i = indexOf(child);
        assert(i>=0, "This is not my child");

        children[i]       = otherChild;
        child.parent      = null;
        otherChild.parent = this;
    }
    int indexOf(ASTNode child) {
        /// Do the happy path first, assuming child is an immediate descendent
        foreach(int i, ch; children[]) {
            if(ch is child) return i;
        }
        /// Do the slower version looking at all descendents
        foreach(int i, ch; children[]) {
            if(ch.hasDescendent(child)) return i;
        }
        return -1;
    }
    ASTNode first() {
        if(children.length == 0) return null;
        return children[0];
    }
    ASTNode last() {
        if(children.length == 0) return null;
        return children[$-1];
    }
    void detach() {
        if(parent) {
            parent.remove(this);
        }
    }
    int index() {
        if(parent) {
            return parent.indexOf(this);
        }
        return -1;
    }
    //=================================================================================
    ASTNode previous() {
        int i = index();
        if(i<1) return parent;
        return parent.children[i-1];
    }
    ASTNode prevSibling() {
        int i = index();
        if(i<1) return null;
        return parent.children[i-1];
    }
    ASTNode[] prevSiblings() {
        int i = index();
        if(i<1) return [];
        return parent.children[0..i];
    }
    ASTNode[] prevSiblingsAndMe() {
        int i = index();
        if(i<0) return [];
        return parent.children[0..i+1];
    }
    ASTNode[] allSiblings() {
        return parent.children[].filter!(it=>it !is this).array;
    }
    ///
    /// Return the root node ie. the node whose parent is Module
    ///
    ASTNode getRoot() {
        assert(this.id!=NodeID.MODULE);
        if(this.parent.id==NodeID.MODULE) return this;
        return parent.getRoot();
    }
    //================================================================================= Dump
    void dumpToConsole(string indent="") {
        //dd(this.id);
        dd("[% 4s] %s".format(this.line+1, indent ~ this.toString()));
        foreach(ch; this.children) {
            ch.dumpToConsole(indent ~ "   ");
        }
    }
    void dump(FileLogger l, string indent="") {
        //debug if(getModule.canonicalName=="tstructs::test_inner_structs") dd(this.id, "line", line);
        l.log("[% 4s] %s", this.line+1, indent ~ this.toString());
        foreach(ch; children) {
            ch.dump(l, indent ~ "   ");
        }
    }
    //=================================================================================
    Container getContainer() inout {
        auto c = cast(Container)parent;
        if(c) return c;
        if(parent) return parent.getContainer();
        throw new Exception("We are not inside a container!!");
    }
    bool hasAncestor(T)() {
        if(parent is null) return false;
        if(parent.isA!T) return true;
        return parent.hasAncestor!T;
    }
    T getAncestor(T)() {
        if(parent is null) return null;
        if(parent.isA!T) return parent.as!T;
        return parent.getAncestor!T;
    }
    /// true if n is our ancestor
    bool isAncestor(ASTNode n) {
        auto p = this.parent;
        while(p && (p !is n)) {
            p = p.parent;
        }
        return (p !is null);
    }
    bool hasDescendent(T)() {
        auto d = cast(T)this;
        if(d) return true;
        foreach(ch; children) {
            if(ch.hasDescendent!T) return true;
        }
        return false;
    }
    /// true if d is our descendent
    bool hasDescendent(ASTNode d) {
        foreach(ch; children) {
            if(ch is d) return true;
            bool r = ch.hasDescendent(d);
            if(r) return true;
        }
        return false;
    }
    T getDescendent(T)() {
        auto d = cast(T)this;
        if(d) return d;
        foreach(ch; children) {
            d = ch.getDescendent!T;
            if(d) return d;
        }
        return null;
    }
    ///
    /// Return a list of all descendents that are of type T.
    ///
    void selectDescendents(T)(Array!T array) {
        auto t = cast(T)this;
        if(t) array.add(t);

        foreach(ch; children) {
            ch.selectDescendents!T(array);
        }
    }
    ///
    /// Collect all nodes where filter returns true, recursively.
    ///
    void recursiveCollect(Array!ASTNode array, bool delegate(ASTNode n) filter) {
        if(filter(this)) array.add(this);
        foreach(n; children) {
            n.recursiveCollect(array, filter);
        }
    }
    void recursiveCollect(T)(Array!T array, bool delegate(T n) filter) {
        T t = this.as!T;
        if(t && filter(t)) array.add(t);
        foreach(n; children) {
            n.recursiveCollect!T(array, filter);
        }
    }
    void recurse(T)(void delegate(T n) functor) {
        if(this.isA!T) functor(this.as!T);
        foreach(n; children) {
            n.recurse!T(functor);
        }
    }
    void recurse(T)(void delegate(int level, T n) functor, int level = 0) {
        if(this.isA!T) functor(level, this.as!T);
        foreach(n; children) {
            n.recurse!T(functor, level+1);
        }
    }
    //===================================================================================
    override size_t toHash() const @trusted {
        assert(nid!=0);
        return nid;
    }
    /// Every node is unique
    override bool opEquals(Object o) const {
        ASTNode foo = cast(ASTNode)o;
        assert(nid && foo.nid);
        return foo && foo.nid==nid;
    }
    override int opCmp(Object o) const {
        ASTNode other = cast(ASTNode)o;
        return nid==other.nid ? 0 :
               nid < other.nid ? -1 : 1;
    }
private:
    Module findModule() {
        if(this.isA!Module) return this.as!Module;
        if(parent) return parent.findModule();
        throw new Exception("We are not attached to a module!!");
    }
}
