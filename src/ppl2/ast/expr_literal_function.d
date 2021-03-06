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

    Closure getClosure() {
        assert(isClosure);
        return parent.as!Closure;
    }
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

    override string toString() {
        return "{} (type=%s)".format(type);
    }
}
