module ppl2.error;

import ppl2.internal;
import core.stdc.stdlib : exit;

//======================================================================
class CompilerError : Exception {
    int line,column;
    Module module_;

    this(Module m, int line, int column, string msg) {
        super(msg);
        this.module_ = m;
        this.line    = line;
        this.column  = column;
    }
    this(Tokens t, string msg) {
        this(t.module_, t.line, t.column, msg);
    }
    this(ASTNode n, string msg) {
        assert(n);
        this(n.getModule, n.line, n.column, msg);
    }
    this(Module m, string msg) {
        this(m, -1, -1, msg);
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
        super(node, "Ambiguous call");
        this.name        = name;
        this.argTypes    = argTypes;
        this.overloadSet = overloadSet;
    }
}
//======================================================================
void warn(Tokens n, string msg) {
   writefln("\nWarn: [%s Line %s] %s", n.module_.getPath(), n.line, msg);
}
//======================================================================
void prettyErrorMsg(CompilerError e) {
    prettyErrorMsg(e.module_, e.line, e.column, e.msg);

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
void prettyErrorMsg(Module m, int line, int col, string msg) {
    string filename = m.getPath();

    void showMessageWithoutLine() {
        writefln("\nError: [%s] %s", filename, msg);
    }
    void showMessageWithLine() {
        writefln("\nError: [%s Line %s] %s", filename, line, msg);
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
    writefln("");
    foreach(m; modules) {
        auto nodes = m.resolver.getUnresolvedNodes();
        if(nodes.length>0) {

            foreach(n; nodes) with(NodeID) {
                bool r = n.id==IDENTIFIER ||
                         n.id==LITERAL_FUNCTION ||
                         n.id==VARIABLE ;
                if(r) {
                    prettyErrorMsg(m, n.line, n.column, "Unresolved symbol");
                } else {
                    writefln("Unresolved %s", n.id);
                }
            }
        }
    }
}
//==============================================================================================

void errorIncompatibleTypes(ASTNode n, Type a, Type b) {
    throw new CompilerError(n,
        "Types are incompatible: %s and %s".format(a.prettyString, b.prettyString));
}
void errorBadSyntax(ASTNode n, string msg) {
    throw new CompilerError(n, msg);
}
void errorBadSyntax(Tokens t, string msg) {
    throw new CompilerError(t, msg);
}
void errorBadImplicitCast(ASTNode n, Type from, Type to) {
    throw new CompilerError(n,
        "Cannot implicitly cast %s to %s".format(from.prettyString(), to.prettyString()));
}
void errorBadNullCast(ASTNode n, Type to) {
    throw new CompilerError(n,
    "Cannot implicitly cast null to %s".format(to.prettyString()));
}
void errorBadExplicitCast(ASTNode n, Type from, Type to) {
    throw new CompilerError(n,
        "Cannot cast %s to %s".format(from.prettyString(), to.prettyString()));
}
void errorModifyingConst(ASTNode n, Identifier i) {
    throw new CompilerError(n,
        "Cannot modify const %s".format(i.name));
}
void errorVarInitMustBeConst(Variable v) {
    throw new CompilerError(v,
        "Const initialiser must be const");
}
void errorArrayCountMustBeConst(ASTNode n) {
    throw new CompilerError(n,
        "Array count expression must be a const");
}
void errorArrayIndexMustBeConst(ASTNode n) {
    throw new CompilerError(n,
        "Array index expression must be a const");
}
void errorMissingType(ASTNode n, string name) {
    throw new CompilerError(n, "Type %s not found".format(name));
}
void errorMissingType(Tokens t, string name=null) {
    if(name) {
        throw new CompilerError(t, "Type %s not found".format(name));
    }
    //throw new Error("!!");
    throw new CompilerError(t, "Type not found");
}
void errorAmbiguousExpr(ASTNode n) {
    throw new CompilerError(n,
        "Parenthesis required to disambiguate these expressions");
}
void errorArrayBounds(ASTNode n, int value, int maxValue) {
    throw new CompilerError(n,
        "Array bounds error. %s >= %s".format(value, maxValue));
}
void newReservedForConstructors(ASTNode n) {
    throw new CompilerError(n,
        "Invalid constructor. Must be a struct or module member");
}
void constructorCannotCallNonDefaultConstructor(ASTNode n) {
    throw new CompilerError(n,
        "Cannot call non-default constructor from within a constructor");
}

void errorArrayLiteralMixedInitialisation(Tokens t) {
    throw new CompilerError(t,
    "Array literals must be either all indexes or all non-indexes");
}
void errorStructLiteralMixedInitialisation(Tokens t) {
    throw new CompilerError(t,
    "Struct literals must be either all named or all unnamed");
}
void aggregateMixedInitialisation(Tokens t) {
    throw new CompilerError(t,
        "Aggregate literals must be either all named or all unnamed");
}