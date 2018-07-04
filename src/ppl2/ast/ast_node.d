module ppl2.ast.ast_node;

import ppl2.internal;

//=============================================================================== NodeID
enum NodeID {
    ARGUMENTS,
    ARRAY,
    FUNC_TYPE,
    MODULE,
    // statements
    ANON_STRUCT,
    DEFINE,
    FUNCTION,
    INITIALISER,
    NAMED_STRUCT,
    RETURN,
    VARIABLE,
    // expressions
    ADDRESS_OF,
    AS,
    ASSERT,
    BINARY,
    CALL,
    COMPOSITE,
    CONSTRUCTOR,
    DEFAULT_INITIALISER,    // remove me later?
    DOT,
    IDENTIFIER,
    IF,
    INDEX,
    LITERAL_ARRAY,
    LITERAL_FUNCTION,
    LITERAL_MAP,
    LITERAL_NULL,
    LITERAL_NUMBER,
    LITERAL_STRING,
    LITERAL_STRUCT,
    MALLOC,
    META_FUNCTION,
    PARENTHESIS,
    STRUCT_CONSTRUCTOR,
    TYPE_EXPR,
    UNARY,
    VALUE_OF,
}
//=============================================================================== ASTNode
T makeNode(T)() {
    T n = new T;
    n.nid = g_nodeid++;
    assert(n.children);
    return n;
}
T makeNode(T)(TokenNavigator t) {
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
bool isDefine(inout ASTNode n) { return n.id()==NodeID.DEFINE; }
bool isDot(inout ASTNode n) { return n.id()==NodeID.DOT; }
bool isExpression(inout ASTNode n) { return n.as!Expression !is null; }
bool isFunction(inout ASTNode n) { return n.id()==NodeID.FUNCTION; }
bool isIdentifier(inout ASTNode n) { return n.id()==NodeID.IDENTIFIER; }
bool isInitialiser(inout ASTNode n) { return n.id()==NodeID.INITIALISER; }
bool isLiteralNull(inout ASTNode n) { return n.id()==NodeID.LITERAL_NULL; }
bool isLiteralNumber(inout ASTNode n) { return n.id()==NodeID.LITERAL_NUMBER; }
bool isLiteralFunction(inout ASTNode n) { return n.id()==NodeID.LITERAL_FUNCTION; }
bool isModule(inout ASTNode n) { return n.id()==NodeID.MODULE; }
bool isNamedStruct(inout ASTNode n) { return n.id()==NodeID.NAMED_STRUCT; }
bool isReturn(inout ASTNode n) { return n.id()==NodeID.RETURN; }
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

    // Override these
    abstract NodeID id() const;
    abstract bool isResolved() { return false; }
    Type getType() { return TYPE_UNKNOWN; }
    string description() { return toString(); }

    bool hasChildren() const { return children.length > 0; }
    int numChildren() const { return cast(int)children.length; }

    void addToFront(ASTNode child) {
        child.detach();
        children.insertAt(child, 0);
        child.parent = this;
    }
    void addToEnd(ASTNode child) {
        child.detach();
        children.add(child);
        child.parent = this;
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
    int indexOf(inout ASTNode child) const {
        foreach(i, ch; children[]) {
            if(ch is child) return cast(int)i;
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
    int index() const {
        if(parent) {
            return parent.indexOf(this);
        }
        return -1;
    }
    //=================================================================================
    inout ASTNode prevSibling() {
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
    T getAncestor(T)() {
        T a = cast(T)parent;
        if(a) return a;
        if(parent.parent) return parent.parent.getAncestor!T();
        return null;
    }
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
    T getContaining(T)() {
        if(parent is null) return null;
        if(parent.isA!T) return parent.as!T;
        return parent.getContaining!T;
    }
    /// This may return null if we are not in a struct
    AnonStruct getContainingStruct() {
        if(parent is null) return null;
        if(parent.isAnonStruct) return parent.as!AnonStruct;
        return parent.getContainingStruct();
    }
    LiteralFunction getContainingFunctionBody() {
        if(parent is null) return null;
        if(parent.isLiteralFunction) return parent.as!LiteralFunction;
        return parent.getContainingFunctionBody();
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