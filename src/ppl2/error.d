module ppl2.error;

import ppl2.internal;
import core.stdc.stdlib : exit;

enum Err {
    GENERIC,
// lexer
    INVALID_CHAR = 1000,
    INVALID_BOOL,
    NOT_A_NUMBER,

    MODULE_DOES_NOT_EXIST,

    EXPORT_NOT_FOUND,
// syntax
    VAR_WITHOUT_INITIALISER = 2000,
    INFER_ARRAY_WITHOUT_INITIALISER,
    BAD_SYNTAX,
    BAD_LHS_EXPR,
    BAD_RHS_EXPR,
    TYPE_INCOMPATIBLE,
    INVALID_OPERATOR,

// resolution
    RETURN_TYPE_MISMATCH = 3000,
    UNRESOLVED_SYMBOL,
    IDENTIFIER_NOT_FOUND,
    FUNCTION_NOT_FOUND,
    IMPORT_NOT_FOUND,
    MISSING_TYPE,

    /// Assert
    ASSERT_FAILED,

    BREAK_MUST_BE_INSIDE_A_LOOP,
    CONTINUE_MUST_BE_INSIDE_A_LOOP,


    BAD_IMPLICIT_CAST = 4000,
    BAD_EXPLICIT_CAST,
    BAD_NULL_CAST,
    NO_PROGRAM_ENTRY_POINT,
    MULTIPLE_ENTRY_POINTS,
    MULTIPLE_MODULE_INITS,

    /// Array
    ARRAY_LITERAL_MIXING_INDEX_AND_NON_INDEX,
    ARRAY_LITERAL_CANNOT_INFER_TYPE,
    ARRAY_LITERAL_TOO_MANY_VALUES,

    /// Index
    INDEX_STRUCT_INDEX_MUST_BE_CONST,

    /// Is
    IS_BOTH_SIDES_MUST_BE_VALUES,
    IS_BOTH_SIDES_MUST_BE_POINTERS,
    IS_BOTH_SIDES_MUST_BE_SAME_SIZE,

    /// struct stuff
    STRUCT_INVALID_MEMBER_INDEX,
    DUPLICATE_STRUCT_MEMBER_NAME,
    ANON_STRUCT_CONTAINS_NON_VARIABLE,
    ANON_STRUCT_CONTAINS_INITIALISER,
    MEMBER_NOT_FOUND,
    DUPLICATE_DEFINITION,
    STRUCT_LITERAL_MEMBER_NOT_FOUND,
    STRUCT_LITERAL_DUPLICATE_NAME,
    STRUCT_LITERAL_TOO_MANY_VALUES,
    STRUCT_LITERAL_MIXING_NAMED_AND_UNNAMED,


    /// Variable stuff
    CONST_VAR_WITHOUT_INITIALISER,
    VAR_INIT_MUST_BE_CONST,
    VAR_MUST_HAVE_EXPLICIT_TYPE,
    VAR_CAN_NOT_BE_CALLED_THIS,
    VAR_MUST_HAVE_A_NAME,

    DUPLICATE_PARAMETER_NAME,
    VAR_DUPLICATE_DECLARATION,
    ARRAY_LITERAL_INDEX_MUST_BE_CONST,
    MODIFYING_CONST,
    AMBIGUOUS_BINARY_EXPR_PRIORITY,
    ARRAY_COUNT_MUST_BE_CONST,
    ARRAY_INDEX_MUST_BE_CONST,
    ARRAY_BOUNDS,
    INCORRECT_RETURN_TYPE,

    /// if
    IF_TYPES_NO_NOT_MATCH,
    IF_USED_AS_RESULT_MUST_HAVE_THEN_AND_ELSE,
    IF_USED_AS_RESULT_MUST_NOT_RETURN,
    IF_USED_AS_RESULT_MUST_NOT_BE_VOID,

    /// Function stuff
    CALL_NEW_RESERVED_FOR_CONSTRUCTORS,
    CALL_CONSTRUCTOR_CALLS_DISALLOWED,
    AMBIGUOUS_CALL,
    CALL_INCORRECT_NUM_ARGS,
    CALL_MIXING_NAMED_AND_UNNAMED,
    CALL_INVALID_PARAM_NAME,
    CALL_INCORRECT_NUM_PARAM_NAMES,
    CALL_DUPLICATE_PARAM_NAME,
    CALL_PARAM_CAN_NOT_BE_CALLED_THIS,
}
//======================================================================
class CompilerError : Exception {
    Err err;
    int line,column;
    Module module_;

    this(Err err, Module m, int line, int column, string msg) {
        super(msg);
        this.module_ = m;
        this.err     = err;
        this.line    = line;
        this.column  = column;
    }
    this(Err err, TokenNavigator t, string msg) {
        this(err, t.module_, t.line, t.column, msg);
    }
    this(Err err, ASTNode n, string msg) {
        assert(n);
        //if(n.line==-1)
        this(err, n.getModule, n.line, n.column, msg);
    }
    this(Err err, Module m, string msg) {
        this(err, m, -1, -1, msg);
    }
}
//======================================================================
final class UnresolvedSymbols : Exception {
    this() {
        super("");
    }
}
final class AmbiguousCall : CompilerError {
    string name;
    Type[] argTypes;
    Array!Callable overloadSet;
    this(ASTNode node, string name, Type[] argTypes, Array!Callable overloadSet) {
        super(Err.AMBIGUOUS_CALL, node, "Ambiguous call");
        this.name        = name;
        this.argTypes    = argTypes;
        this.overloadSet = overloadSet;
    }
}
//======================================================================
void warn(TokenNavigator n, string msg) {
    writefln("Warn: %s", msg);
}
//======================================================================
void prettyErrorMsg(CompilerError e) {
    prettyErrorMsg(e.module_, e.line, e.column, cast(int)e.err, e.msg);

    auto ambiguous = e.as!AmbiguousCall;
    if(ambiguous) {
        writefln("\nLooking for:");
        writefln("\n\t%s(%s)", ambiguous.name, ambiguous.argTypes.prettyString);

        writefln("\n%s matches found:\n", ambiguous.overloadSet.length);

        foreach(callable; ambiguous.overloadSet) {
            auto params       = callable.getType().getFunctionType.paramTypes();
            string moduleName = callable.getModule.canonicalName;
            int line          = callable.getNode.line;
            writefln("\t%s(%s) \t:: %s:%s", ambiguous.name, prettyString(params), moduleName, line);
        }
    }
}
void prettyErrorMsg(Module m, int line, int col, int errNum, string msg) {
    string filename = m.getPath();

    void showMessageWithoutLine() {
        writefln("\nError %s: [%s] %s", errNum, filename, msg);
    }
    void showMessageWithLine() {
        writefln("\nError %s: [%s Line %s] %s", errNum, filename, line, msg);
    }

    if(line==-1 || col==-1) {
        showMessageWithoutLine();
        return;
    }

    import std.stdio;

    auto lines = File(filename, "rb").byLineCopy().array;

    if(lines.length<=line-1) {
        showMessageWithoutLine();
        return;
    }

    showMessageWithLine();

    string spaces;
    for(int i=0; i<col; i++) { spaces ~= " "; }
    writefln("\n%s|", spaces);
    writefln("%sv", spaces);
    writefln("%s", lines[line-1]);
}
//==============================================================================================
void displayUnresolved(Module[] modules) {
    foreach(m; modules) {
        auto nodes = m.resolver.getUnresolvedNodes();
        if(nodes.length>0) {

            foreach(n; nodes) {
                prettyErrorMsg(m, n.line, n.column, Err.UNRESOLVED_SYMBOL,
                    "Unresolved symbol");
            }
        }
    }
}
//==============================================================================================

void errorIncompatibleTypes(ASTNode n, Type a, Type b) {
    throw new CompilerError(Err.TYPE_INCOMPATIBLE, n,
        "Types are incompatible: %s and %s".format(a.prettyString, b.prettyString));
}
void errorBadSyntax(ASTNode n, string msg) {
    throw new CompilerError(Err.BAD_SYNTAX, n, msg);
}
void errorBadSyntax(TokenNavigator t, string msg) {
    throw new CompilerError(Err.BAD_SYNTAX, t, msg);
}
void errorBadImplicitCast(ASTNode n, Type from, Type to) {
    throw new CompilerError(Err.BAD_IMPLICIT_CAST, n,
        "Cannot implicitly cast %s to %s".format(from.prettyString(), to.prettyString()));
}
void errorBadNullCast(ASTNode n, Type to) {
    throw new CompilerError(Err.BAD_NULL_CAST, n,
    "Cannot implicitly cast null to %s".format(to.prettyString()));
}
void errorBadExplicitCast(ASTNode n, Type from, Type to) {
    throw new CompilerError(Err.BAD_EXPLICIT_CAST, n,
        "Cannot cast %s to %s".format(from.prettyString(), to.prettyString()));
}
void errorModifyingConst(ASTNode n, Identifier i) {
    throw new CompilerError(Err.MODIFYING_CONST, n,
        "Cannot modify const %s".format(i.name));
}
void errorVarInitMustBeConst(Variable v) {
    throw new CompilerError(Err.VAR_INIT_MUST_BE_CONST, v,
        "Const initialiser must be const");
}
void errorArrayCountMustBeConst(ASTNode n) {
    throw new CompilerError(Err.ARRAY_COUNT_MUST_BE_CONST, n,
        "Array count expression must be a const");
}
void errorArrayIndexMustBeConst(ASTNode n) {
    throw new CompilerError(Err.ARRAY_INDEX_MUST_BE_CONST, n,
        "Array index expression must be a const");
}
void errorArrayLiteralMixedInitialisation(TokenNavigator t) {
    throw new CompilerError(Err.ARRAY_LITERAL_MIXING_INDEX_AND_NON_INDEX, t,
        "Array literals must be either all indexes or all non-indexes");
}
void errorStructLiteralMixedInitialisation(TokenNavigator t) {
    throw new CompilerError(Err.STRUCT_LITERAL_MIXING_NAMED_AND_UNNAMED, t,
        "Struct literals must be either all named or all unnamed");
}
void errorMissingType(ASTNode n, string name) {
    throw new CompilerError(Err.MISSING_TYPE, n, "Type %s not found".format(name));
}
void errorMissingType(TokenNavigator t, string name) {
    throw new CompilerError(Err.MISSING_TYPE, t, "Type %s not found".format(name));
}
void errorAmbiguousExpr(ASTNode n) {
    throw new CompilerError(Err.AMBIGUOUS_BINARY_EXPR_PRIORITY, n,
        "Parenthesis required to disambiguate these expressions");
}
void errorArrayBounds(ASTNode n, int value, int maxValue) {
    throw new CompilerError(Err.ARRAY_BOUNDS, n,
        "Array bounds error. %s >= %s".format(value, maxValue));
}
void errorIncorrectReturnType(ASTNode n, string msg) {
    throw new CompilerError(Err.INCORRECT_RETURN_TYPE, n, msg);
}
void newReservedForConstructors(ASTNode n) {
    throw new CompilerError(Err.CALL_NEW_RESERVED_FOR_CONSTRUCTORS, n,
        "Invalid constructor. Must be a struct or module member");
}
void constructorCannotCallNonDefaultConstructor(ASTNode n) {
    throw new CompilerError(Err.CALL_NEW_RESERVED_FOR_CONSTRUCTORS, n,
        "Cannot call non-default constructor from within a constructor");
}
