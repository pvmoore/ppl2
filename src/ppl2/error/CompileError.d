module ppl2.error.CompileError;

import ppl2.internal;

//====================================================================================
abstract class CompileError {
protected:
public:
    int id;
    int line;
    int column;
    Module module_;

    this(Module module_, int line, int column) {
        this.id      = g_errorIDs++;
        this.module_ = module_;
        this.line    = line;
        this.column  = column;
    }
    abstract string getKey();
    abstract string toPrettyString();
protected:
    string prettyErrorMsg(Module module_, string msg) {
        auto buf = new StringBuffer;

        void showMessageWithoutLine() {
            buf.add("Error: [%s] %s\n", module_.fullPath, msg);
        }
        void showMessageWithLine() {
            buf.add("Error: [%s Line %s:%s] %s\n", module_.fullPath, line+1, column, msg);
        }

        if(line==-1 || column==-1) {
            showMessageWithoutLine();
            return buf.toString();
        }

        auto lines = From!"std.stdio".File(module_.fullPath, "rb").byLineCopy().array;

        if(lines.length<=line) {
            showMessageWithoutLine();
            return buf.toString();
        }

        showMessageWithLine();

        string spaces;
        for(int i=0; i<column; i++) { spaces ~= " "; }

        auto errorLineStr = convertTabsToSpaces(lines[line]);

        buf.add("\n%s|\n", spaces);
        buf.add("%sv\n", spaces);
        buf.add("%s", errorLineStr);

        return buf.toString();
    }
}
//====================================================================================
final class TokeniseError : CompileError {
private:
    string msg;
public:
    this(Module m, int line, int column, string msg) {
        super(m, line, column);
        this.msg     = msg;
    }
    override string getKey() {
        return "%s|%s|%s|%s".format(module_.canonicalName, line, column, msg);
    }
    override string toPrettyString() {
        return prettyErrorMsg(module_, msg);
    }
}
//====================================================================================
final class ParseError : CompileError {
private:
    Tokens tokens;
    ASTNode node;
    string msg;
public:
    this(Module m, Tokens t, string msg) {
        super(m, t.line, t.column);
        this.tokens = t;
        this.msg    = msg;
    }
    this(Module m, ASTNode n, string msg) {
        super(m, n.line, n.column);
        this.node = n;
        this.msg  = msg;
    }
    override string getKey() {
        return "%s|%s|%s".format(module_.canonicalName, line, column);
    }
    override string toPrettyString() {
        return prettyErrorMsg(module_, msg);
    }
}
//====================================================================================
final class UnknownError : CompileError {
private:
    string msg;
public:
    this(Module m, string msg) {
        super(m, 0, 0);
        this.msg = msg;
    }
    override string getKey() {
        return "%s".format(msg);
    }
    override string toPrettyString() {
        return msg;
    }
}
//====================================================================================
final class AmbiguousCall : CompileError {
private:
    Call call;
    string name;
    Type[] argTypes;
    Callable[] overloadSet;
    Function[] templateFunctions;
    Type[][] templateParams;
public:
    this(Module m, Call call, Array!Callable overloadSet) {
        super(m, call.line, call.column);
        this.call        = call;
        this.overloadSet = overloadSet.values.dup;
    }
    this(Module m, Call call, Function[] templateFunctions, Type[][] templateParams) {
        super(m, call.line, call.column);
        this.call              = call;
        this.templateFunctions = templateFunctions;
        this.templateParams    = templateParams;
    }
    override string getKey() {
        return "%s|%s|%s".format(module_.canonicalName, call.line, call.column);
    }
    override string toPrettyString() {
        auto buf = new StringBuffer;

        buf.add(prettyErrorMsg(module_, "Ambiguous call"));

        auto numMatches = overloadSet.length + templateFunctions.length;

        buf.add("\n\n\t%s matches found:\n\n", numMatches);

        string getFuncSignature(Type[] params, Type retType) {
            string a = params.length==0 ? "void" : params.toString;
            return "{%s -> %s}".format(a, retType);
        }

        foreach(i, f; templateFunctions) {
            string moduleName = f.getModule.canonicalName;
            auto paramTokens  = f.blueprint.getParamTokens();

            string s1 = "%s Line %4s:%-2s".format(moduleName, f.line+1, f.column);
            string s2 = "%35s\t%s <%s>".format(s1, call.name,
                templateParams[i].toString);

            buf.add("\t%s\n", s2);
        }

        foreach(callable; overloadSet) {
            auto funcType     = callable.getType().getFunctionType;
            auto params       = funcType.paramTypes();
            auto retType      = funcType.returnType();
            string moduleName = callable.getModule.canonicalName;
            auto node         = callable.getNode;

            string s1 = "%s Line %4s:%-2s".format(moduleName, node.line+1, node.column);
            string s2 = "%35s\t%s %s".format(s1, call.name, getFuncSignature(params, retType));

            buf.add("\t%s\n", s2);
        }
        return buf.toString();
    }
}
//====================================================================================
final class LinkError : CompileError {
private:
    int status;
    string msg;
public:
    this(Module m, int status, string msg) {
        super(m, 0, 0);
        this.status  = status;
        this.msg     = msg;
    }
    override string getKey() {
        return "%s|%s".format(status, msg);
    }
    override string toPrettyString() {
        return "Link error: Status code: %s, msg: %s".format(status, msg);
    }
}
//====================================================================================
void warn(Tokens n, string msg) {
    writefln("WARN [%s Line %s] %s", n.module_.fullPath, n.line, msg);
}
void errorBadSyntax(Module m, ASTNode n, string msg) {
    m.addError(n, msg, false);
}
void errorBadSyntax(Module m, Tokens t, string msg) {
    m.addError(t, msg, false);
}
void errorBadImplicitCast(Module m, ASTNode n, Type from, Type to) {
    //throw new Error("");
    m.addError(n, "Cannot implicitly cast %s to %s".format(from, to), true);
}
void errorBadExplicitCast(Module m, ASTNode n, Type from, Type to) {
    m.addError(n, "Cannot cast %s to %s".format(from, to), true);
}

void errorMissingType(Module m, ASTNode n, string name) {
    m.addError(n, "Type %s not found".format(name), true);
}
void errorMissingType(Module m, Tokens t, string name=null) {
    if(name) {
        m.addError(t, "Type %s not found".format(name), true);
    } else {
        m.addError(t, "Type not found", true);
    }
}