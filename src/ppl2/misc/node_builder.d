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

    Identifier identifier(Variable v) {
        auto id   = makeNode!Identifier(node);
        id.target = new Target(module_);
        id.name   = v.name;

        if(v.isStructMember) {
            auto struct_ = v.parent.as!AnonStruct;
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
        i.addToEnd(left);
        i.addToEnd(right);
        return i;
    }
    Variable variable(string name, Type t, bool isConst = false) {
        auto var    = makeNode!Variable(node);
        var.name    = name;
        var.type    = t;
        var.isConst = isConst;
        return var;
    }
    Binary binary(Operator op, Expression left, Expression right, Type type=TYPE_UNKNOWN) {
        auto b = makeNode!Binary(node);
        b.type = type;
        b.op   = op;

        b.addToEnd(left);
        b.addToEnd(right);
        return b;
    }
    Call call(string name, Function f) {
        auto call   = makeNode!Call(node);
        call.target = new Target(module_);
        call.name   = name;
        if(f) {
            if(f.isStructMember) {
                auto struct_ = f.parent.as!AnonStruct;
                assert(struct_);
                call.target.set(f, struct_.getMemberIndex(f));
            } else {
                call.target.set(f);
            }
        }
        return call;
    }
    Return return_(Expression expr) {
        auto ret = makeNode!Return(node);
        ret.addToEnd(expr);
        return ret;
    }
    AddressOf addressOf(Expression expr) {
        auto a = makeNode!AddressOf(node);
        a.addToEnd(expr);
        return a;
    }
    ValueOf valueOf(Expression expr) {
        auto v = makeNode!ValueOf(node);
        v.addToEnd(expr);
        return v;
    }
    Dot dot(Expression left, Expression right) {
        auto d = makeNode!Dot(node);
        d.addToEnd(left);
        d.addToEnd(right);
        return d;
    }
    TypeExpr typeExpr(Type t) {
        auto e = makeNode!TypeExpr(node);
        e.type = t;
        return e;
    }
}

