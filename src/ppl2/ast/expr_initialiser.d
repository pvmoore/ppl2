module ppl2.ast.expr_initialiser;

import ppl2.internal;
///
/// Variable initialiser.
///
final class Initialiser : Expression {
private:
    bool astGenerated;
    LiteralNumber _literal;
public:
    Variable var;

    override bool isResolved() { return astGenerated; }
    override bool isConst() { return var.isConst; }
    override int priority() const { return 15; }
    override NodeID id() const { return NodeID.INITIALISER; }
    override Type getType() {
        if(var.type.isKnown) return var.type;
        if(hasChildren) {
            return last().getType;
        }
        return TYPE_UNKNOWN;
    }
    ///
    /// Return either LiteralNumber or null.
    ///
    LiteralNumber literal() {
        return _literal;
    }

    void resolve() {
        if(astGenerated) return;
        if(var.type.isUnknown && !var.isImplicit) return;
        if(!areResolved(children[])) return;

        /// Generate initialisation AST for our parent Variable
        if(numChildren > 0) {
            /// Initialisation provided by the user
            assert(last().isExpression, "last is a %s".format(last()));
            assert(numChildren==1);

            if(!var.type.isPtr && var.type.isStruct) {
                /// Already assignments
            } else {
                convertToAssignment();
            }
        } else {
            /// We need to generate some initialisation code

            auto type = var.type;
            assert(!type.isDefine, "%s".format(type));

            if(type.isPtr) {
                gen(type.as!PtrType);
            } else if(type.isBasicType) {
                gen(type.getBasicType);
            } else if(type.isNamedStruct) {
                gen(type.getNamedStruct);
            } else if(type.isStruct) {
                gen(type.getAnonStruct);
            } else if(type.isArray) {
                gen(type.getArrayType);
            } else {
                assert(type.isFunction);
                gen(type.getFunctionType);
            }
        }

        astGenerated = true;
    }

    override string toString() {
        return "Initialiser (type=%s)".format(getType);
    }
private:
    void convertToAssignment() {
        _literal = last().as!LiteralNumber;
        auto b      = getModule.builder(var);
        auto assign = b.binary(Operator.ASSIGN, b.identifier(var), last().as!Expression, var.type);
        addToEnd(assign);
    }
    void gen(PtrType ptr) {
        addToEnd(LiteralNull.makeConst(var.type));
        convertToAssignment();
    }
    void gen(BasicType basic) {
        addToEnd(basic.defaultInitialiser());
        convertToAssignment();
    }
    void gen(NamedStruct ns) {
        auto b = getModule.builder(var);

        auto id        = b.identifier(var.name);
        auto thisPtr   = b.addressOf(id);

        auto call     = b.call("new", null);
        call.addToEnd(thisPtr);
        auto dot      = b.dot(b.identifier(id.name), call);

        addToEnd(dot);
    }
    void gen(AnonStruct struct_) {
        auto b = getModule.builder(var);

        foreach(i, mv; struct_.getMemberVariables()) {
            auto index  = b.index(b.identifier(var), LiteralNumber.makeConst(i, TYPE_INT));
            auto assign = b.binary(Operator.ASSIGN, index, mv.type.defaultInitialiser(), mv.type);
            addToEnd(assign);
        }
    }
    void gen(ArrayType array) {
        addToEnd(array.defaultInitialiser());
        convertToAssignment();
    }
    void gen(FunctionType func) {
        addToEnd(LiteralNull.makeConst(var.type));
        convertToAssignment();
    }
}