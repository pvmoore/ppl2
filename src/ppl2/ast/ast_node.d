module ppl2.ast.ast_node;

import ppl2.internal;

//=============================================================================== NodeID
enum NodeID {
    ADDRESS_OF,
    ANON_STRUCT,
    ARRAY_STRUCT,
    AS,
    ASSERT,
    BINARY,
    BREAK,
    CALL,
    CALLOC,
    CLOSURE,
    COMPOSITE,
    CONSTRUCTOR,
    CONTINUE,
    DEFINE,
    DOT,
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
    LITERAL_STRUCT,
    LOOP,
    META_FUNCTION,
    MODULE,
    NAMED_STRUCT,
    PARAMETERS,
    PARENTHESIS,
    RETURN,
    STRUCT_CONSTRUCTOR,
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
bool isAnonStruct(inout ASTNode n) { return n.id()==NodeID.ANON_STRUCT; }
bool isAs(inout ASTNode n) { return n.id()==NodeID.AS; }
bool isBinary(inout ASTNode n) { return n.id()==NodeID.BINARY; }
bool isCall(inout ASTNode n) { return n.id()==NodeID.CALL; }
bool isComposite(inout ASTNode n) { return n.id()==NodeID.COMPOSITE; }
bool isDefine(inout ASTNode n) { return n.id()==NodeID.DEFINE; }
bool isDot(inout ASTNode n) { return n.id()==NodeID.DOT; }
bool isExpression(inout ASTNode n) { return n.as!Expression !is null; }
bool isFunction(inout ASTNode n) { return n.id()==NodeID.FUNCTION; }
bool isIdentifier(inout ASTNode n) { return n.id()==NodeID.IDENTIFIER; }
bool isIf(inout ASTNode n) { return n.id()==NodeID.IF; }
bool isIndex(inout ASTNode n) { return n.id()==NodeID.INDEX; }
bool isInitialiser(inout ASTNode n) { return n.id()==NodeID.INITIALISER; }
bool isLiteralNull(inout ASTNode n) { return n.id()==NodeID.LITERAL_NULL; }
bool isLiteralNumber(inout ASTNode n) { return n.id()==NodeID.LITERAL_NUMBER; }
bool isLiteralFunction(inout ASTNode n) { return n.id()==NodeID.LITERAL_FUNCTION; }
bool isLoop(inout ASTNode n) { return n.id()==NodeID.LOOP; }
bool isModule(inout ASTNode n) { return n.id()==NodeID.MODULE; }
bool isNamedStruct(inout ASTNode n) { return n.id()==NodeID.NAMED_STRUCT; }
bool isReturn(inout ASTNode n) { return n.id()==NodeID.RETURN; }
bool isTypeExpr(inout ASTNode n) { return n.id()==NodeID.TYPE_EXPR; }
bool isVariable(inout ASTNode n) { return n.id()==NodeID.VARIABLE; }

bool areAll(NodeID ID)(ASTNode[] n) { return n.all!(it=>it.id==ID); }
bool areResolved(ASTNode[] nodes) { return nodes.all!(it=>it.isResolved); }
bool areResolved(Expression[] nodes) { return nodes.all!(it=>it.isResolved); }
bool areResolved(Variable[] nodes) { return nodes.all!(it=>it.isResolved); }

abstract class ASTNode {
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
    Type getType() { return TYPE_UNKNOWN; }
    string description() { return toString(); }
/// end

    bool hasChildren() const { return children.length > 0; }
    int numChildren() const { return cast(int)children.length; }

    auto addToFront(ASTNode child) {
        child.detach();
        children.insertAt(child, 0);
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
        children.insertAt(child, index);
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
        auto child = children.removeAt(children.length-1);
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
        dd("[% 4s] %s".format(this.line, indent ~ this.toString()));
        foreach(ch; this.children) {
            ch.dumpToConsole(indent ~ "   ");
        }
    }
    void dump(FileLogger l, string indent="") {
        //dd("line", line, typeid(this));
        //dd(this);
        l.log("[% 4s] %s", this.line, indent ~ description());
        foreach(ch; children) {
            ch.dump(l, indent ~ "   ");
        }
    }
    //=================================================================================
    Module getModule() {
        if(this.isA!Module) return this.as!Module;
        if(parent) return parent.getModule();
        throw new Exception("We are not attached to a module!!");
    }
    inout Container getContainer() {
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
}