module ppl2.ast.expr_literal_function;

import ppl2.internal;

///
/// literal_function::= "{" [ { arg_list } "->" ] { statement } "}"    
/// arg_list ::= type identifier { "," type identifier }               
///                                                                    
/// LiteralFunction                                                    
///     Arguments
///         Variable (0 - *)
///     statement (0 - *)
///
class LiteralFunction : Expression, Scope, Container {
    FunctionType type;

    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.LITERAL_FUNCTION; }
    override int priority() const { return 15; }
    override Type getType() { return type; }

    Arguments args() {
        return children[0].as!Arguments;
    }

    bool isClosure() const {
        return getContainer().id()==NodeID.LITERAL_FUNCTION;
    }

    bool isTemplate() { return false; }

    Function getFunction() {
        assert(parent.isA!Function);
        return parent.as!Function;
    }
    Return[] getReturns() {
        auto array = new Array!Return;
        selectDescendents!Return(array);
        return array[].filter!(it=>
            /// Don't include closure or inner struct
            it.getContainer().node.nid==nid
        ).array;
    }
    Call[] getCalls() {
        auto array = new Array!Call;
        selectDescendents!Call(array);
        return array[].filter!(it=>
            /// Don't include closure or inner struct
            it.getContainer().node.nid==nid
        ).array;
    }

    ///
    /// Look through returns. All returns must be implicitly castable  
    /// to a single base type.                                         
    /// If there are no returns then the return type is void.          
    ///
    Type determineReturnType() {
        Type rt;

        void setTypeTo(Type t) {
            if(rt is null) {
                rt = t;
            } else {
                rt = getBestFit(t, rt);
                if(type is null) {
                    throw new CompilerError(Err.RETURN_TYPE_MISMATCH, this,
                        "All return types must be implicitly castable to the largest return type");
                }
            }
        }

        foreach(r; getReturns()) {
            if(r.hasExpr) {
                if(r.expr().getType.isUnknown) return TYPE_UNKNOWN;
                setTypeTo(r.expr().getType);
            } else {
                setTypeTo(TYPE_VOID);
            }
        }
        if(rt) return rt;
        return TYPE_VOID;
    }

    override string toString() {
        return "{} (type=%s)".format(type);
    }
}
//=========================================================================================
final class LiteralFunctionTemplate : LiteralFunction {
    string[] templateArgNames;
    Token[] tokens;

    override bool isTemplate() { return true; }


    /// Extract this template
    LiteralFunction extract(Type[] types) {
        assert(false, "extract literal func template");
    }

    override string toString() {
        string s = " <" ~ templateArgNames.join(",") ~ ">";
        return "%s {}".format(s);
    }
}