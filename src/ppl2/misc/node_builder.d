module ppl2.misc.node_builder;

import ppl2.internal;

final class NodeBuilder {
    Module module_;
    ASTNode node;

    this(Module module_) {
        this.module_ = module_;
    }

    NodeBuilder forNode(ASTNode n) {
        this.node = n;
        return this;
    }

    AddressOf addressOf(Expression expr) {
        auto a = makeNode!AddressOf(node);
        a.add(expr);
        return a;
    }
    As as(Expression left, Type type) {
        auto a = makeNode!As(node);
        a.add(left);
        a.add(typeExpr(type));
        return a;
    }
    Binary assign(Expression left, Expression right, Type type=TYPE_UNKNOWN) {
        auto b = makeNode!Binary(node);
        b.type = type;
        b.op   = Operator.ASSIGN;

        b.add(left);
        b.add(right);
        return b;
    }
    Binary or(Expression left, Expression right, Type type=TYPE_UNKNOWN) {
        auto b = makeNode!Binary(node);
        b.type = type;
        b.op   = Operator.BOOL_OR;

        b.add(left);
        b.add(right);
        return b;
    }
    Binary binary(Operator op, Expression left, Expression right, Type type=TYPE_UNKNOWN) {
        auto b = makeNode!Binary(node);
        b.type = type;
        b.op   = op;

        b.add(left);
        b.add(right);
        return b;
    }
    Call call(string name, Function f = null) {
        auto call   = makeNode!Call(node);
        call.target = new Target(module_);
        call.name   = name;
        if(f) {
            if(f.isStructMember) {
                auto tuple = f.parent.as!Tuple;
                assert(tuple);
                auto ns = tuple.parent.as!Struct;
                assert(ns);
                call.target.set(f, ns.getMemberIndex(f));
            } else {
                call.target.set(f);
            }
        }
        return call;
    }
    /// eg. GC.start()
    /// Dot
    ///     TypeExpr
    ///     identifier
    Expression callStatic(string typeName, string memberName, ASTNode parent) {
        Type t = module_.typeFinder.findType(typeName, parent);
        assert(t);
        return dot(typeExpr(t), call(memberName));
    }
    Dot dot(ASTNode left, ASTNode right) {
        auto d = makeNode!Dot(node);
        d.add(left);
        d.add(right);
        return d;
    }
    EnumMember enumMember(Enum enum_, Expression expr) {
        auto em = makeNode!EnumMember(node);
        em.name = module_.makeTemporary("");
        em.type = enum_;
        em.add(expr);
        return em;
    }
    EnumMemberValue enumMemberValue(Enum enum_, Expression expr) {
        auto emv  = makeNode!EnumMemberValue(node);
        emv.enum_ = enum_;
        emv.add(expr);
        return emv;
    }
    Function function_(string name) {
        Function f   = makeNode!Function(node);
        f.name       = name;
        f.moduleName = module_.canonicalName;

        auto body_ = makeNode!LiteralFunction(node);

        auto params = makeNode!Parameters(node);
        body_.add(params);

        auto type   = makeNode!FunctionType(node);
        type.params = params;
        body_.type  = Pointer.of(type, 1);

        f.add(body_);

        return f;
    }
    Identifier identifier(Variable v) {
        auto id   = makeNode!Identifier(node);
        id.target = new Target(module_);
        id.name   = v.name;

        if(v.isTupleMember) {
            auto tuple = v.parent.as!Tuple;
            assert(tuple);
            id.target.set(v, tuple.getMemberIndex(v));
        } else if(v.isStructMember) {
            auto struct_ = v.parent.as!Struct;
            assert(struct_);
            id.target.set(v, struct_.getMemberIndex(v));
        } else {
            id.target.set(v);
        }
        return id;
    }
    Identifier identifier(string name) {
        auto id   = makeNode!Identifier(node);
        id.target = new Target(module_);
        id.name   = name;
        return id;
    }
    Index index(Expression left, Expression right) {
        auto i = makeNode!Index(node);
        i.add(left);
        i.add(right);
        return i;
    }
    Expression integer(int value) {
        return LiteralNumber.makeConst(value, TYPE_INT);
    }
    Return return_(Expression expr) {
        auto ret = makeNode!Return(node);
        ret.add(expr);
        return ret;
    }
    TypeExpr typeExpr(Type t) {
        auto e = makeNode!TypeExpr(node);
        e.type = t;
        return e;
    }
    Unary unary(Operator op, Expression expr) {
        auto u = makeNode!Unary(node);
        u.op = op;
        u.add(expr);
        return u;
    }
    Unary not(Expression expr) {
        auto u = makeNode!Unary(node);
        u.op = Operator.BOOL_NOT;
        u.add(expr);
        return u;
    }
    ValueOf valueOf(Expression expr) {
        auto v = makeNode!ValueOf(node);
        v.add(expr);
        return v;
    }
    Variable variable(string name, Type t, bool isConst = false) {
        auto var    = makeNode!Variable(node);
        var.name    = name;
        var.type    = t;
        var.isConst = isConst;
        return var;
    }

    Constructor string_(LiteralString lit) {
        /// Create an alloca
        auto con = makeNode!Constructor(node);
        con.type = module_.typeFinder.findType("string", module_);

        auto var = variable(module_.makeTemporary("str"), con.type);
        con.add(var);

        /// Call string.new(this, byte*, int)
        Call call = call("new");
            call.add(addressOf(identifier(var.name)));
            call.add(lit);
            call.add(LiteralNumber.makeConst(lit.calculateLength(), TYPE_INT));

        //auto dot = dot(identifier(var.name), call);

        //auto valueof = valueOf(dot);
        con.add(valueOf(dot(identifier(var.name), call)));
        return con;
    }
}

