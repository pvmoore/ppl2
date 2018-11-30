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
final class LiteralFunction : Expression, Container {
    Type type;      /// Pointer -> FunctionType

    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.LITERAL_FUNCTION; }
    override int priority() const { return 15; }
    override Type getType() { return type; }

    LLVMValueRef getLLVMValue() {
        if(isClosure) return parent.as!Closure.llvmValue;
        return getFunction().llvmValue;
    }

    Parameters params() {
        return children[0].as!Parameters;
    }

    bool isClosure() const {
        return parent.isA!Closure;
    }

    bool isTemplate() { return false; }

    Function getFunction() {
        assert(parent.isA!Function);
        return parent.as!Function;
    }
    Return[] getReturns() {
        auto array = new DynamicArray!Return;
        selectDescendents!Return(array);
        return array[].filter!(it=>
            /// Don't include closure or inner struct
            it.getContainer().node.nid==nid
        ).array;
    }
    Call[] getCalls() {
        auto array = new DynamicArray!Call;
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
                    getModule.addError(this, "All return types must be implicitly castable to the largest return type", true);
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
