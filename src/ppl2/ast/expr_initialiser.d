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
        assert(numChildren>0);

        //if(var.type.isNamedStruct) {
        //    convertToAssignment();
        //} else if(var.type.isAnonStruct) {
        //    convertToAssignment();
        //} else {
        //    convertToAssignment();
        //}
        convertToAssignment();

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
}