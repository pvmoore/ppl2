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
        assert(var);
        if(var.type.isKnown) return var.type;
        if(hasChildren && last().isResolved) {
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
        assert(var);
        if(astGenerated) return;
        if(var.type.isUnknown && !var.isImplicit) return;
        if(!areResolved(children[])) return;

        /// Generate initialisation AST for our parent Variable
        assert(numChildren==1);

        convertToAssignment();

        astGenerated = true;
    }

    override string toString() {
        assert(var);
        return "Initialiser var=%s, type=%s".format(var.name, getType);
    }
private:
    void convertToAssignment() {
        _literal = last().as!LiteralNumber;
        auto b      = getModule.builder(var);
        auto assign = b.binary(Operator.ASSIGN, b.identifier(var), last().as!Expression, var.type);
        add(assign);
    }
}