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
    Binary binary(Operator op, Expression left, Expression right, Type type=TYPE_UNKNOWN) {
        auto b = makeNode!Binary(node);
        b.type = type;
        b.op   = op;

        b.add(left);
        b.add(right);
        return b;
    }
    Call call(string name, Function f) {
        auto call   = makeNode!Call(node);
        call.target = new Target(module_);
        call.name   = name;
        if(f) {
            if(f.isStructMember) {
                auto tuple = f.parent.as!Tuple;
                assert(tuple);
                auto ns = tuple.parent.as!NamedStruct;
                assert(ns);
                call.target.set(f, ns.getMemberIndex(f));
            } else {
                call.target.set(f);
            }
        }
        return call;
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
    Identifier identifier(Variable v) {
        auto id   = makeNode!Identifier(node);
        id.target = new Target(module_);
        id.name   = v.name;

        if(v.isTupleMember || v.isNamedStructMember) {
            auto tuple = v.parent.as!Tuple;
            assert(tuple);
            id.target.set(v, tuple.getMemberIndex(v));
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
        Call call = call("new", null);
            call.add(addressOf(identifier(var.name)));
            call.add(lit);
            call.add(LiteralNumber.makeConst(lit.calculateLength(), TYPE_INT));

        //auto dot = dot(identifier(var.name), call);

        //auto valueof = valueOf(dot);
        con.add(valueOf(dot(identifier(var.name), call)));
        return con;
    }
}

