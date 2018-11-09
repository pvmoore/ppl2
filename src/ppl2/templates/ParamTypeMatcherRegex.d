module ppl2.templates.ParamTypeMatcherRegex;
///
/// Match a template function using regex.
/// eg.
///     call     func   ( int[2] )
///     template func<A>( A  [2] )
///     regex pattern =  (.*)\[2\] => this matches with the capture being "int"
///
/// The captures are converted to types and used as the template parameters.
///
import ppl2.internal;
import std.regex;

final class ParamTypeMatcherRegex {
private:
    Module module_;
    Call call;
    Function func;
    string[] proxies;
    Type[string] hash;
    StringBuffer buf, buf2;
    Lexer lexer;
public:
    this(Module module_) {
        this.module_ = module_;
        this.lexer   = new Lexer(module_);
        this.buf     = new StringBuffer;
        this.buf2    = new StringBuffer;
    }
    bool getEstimatedParams(Call call, Function f, ref Type[] estimatedParams) {
        this.call    = call;
        this.func    = f;
        this.proxies = f.blueprint.paramNames;
        this.hash.clear();

        chat("====> ParamTypeMatcherRegex for %s(%s) => template %s<%s>(%s)",
            f.name, call.argTypes.toString, f.name,
            f.blueprint.paramNames.toString(),
            f.blueprint.getParamTokens().getTokensForAllParams().map!(it=>it.toSimpleString));

        auto paramTokens = f.blueprint.getParamTokens();

        foreach(int i, callType; call.argTypes) {
            chat("Arg %s", i);

            Token[] tokens = paramTokens.getTokensForParam(i);

            if(!containsProxy(tokens)) {
                chat("\tNo proxies");
                continue;
            }

            matchArg(i, tokens, callType);
        }
        if(hash.length==f.blueprint.numTemplateParams) {
            chat("Hash = %s", hash);
            estimatedParams = new Type[proxies.length];
            for(auto n=0; n<estimatedParams.length; n++) {
                estimatedParams[n] = hash.get(proxies[n], TYPE_VOID);
            }
            bool result = checkEstimate(f, estimatedParams);
            chat("Match: %s<%s> --> %s", f.name, estimatedParams.toString(), result ? "Pass" : "Fail");
            return result;
        }
        chat("No match");
        return false;
    }
private:
    void chat(A...)(lazy string fmt, lazy A args) {
        static if(false) {
            dd(format(fmt, args));
        }
    }
    void addToHash(string proxy, Type type) {
        import common : containsKey;

        if(hash.containsKey(proxy)) {
            Type old = hash[proxy];
            if(areCompatible(old, type)) {
                hash[proxy] = getBestFit(old, type);
            } else {
                hash[proxy] = type;
            }
        } else {
            hash[proxy] = type;
        }
    }
    bool isProxy(Token tok) const {
        import common : contains;
        return tok.type==TT.IDENTIFIER && proxies.contains(tok.value);
    }
    bool containsProxy(Token[] tokens) const {
        foreach(tok; tokens) if(isProxy(tok)) return true;
        return false;
    }
    bool checkEstimate(Function f, Type[] estimatedParams) {

        Type[] paramTypes = f.blueprint.getFuncParamTypes(module_, call, estimatedParams);
        //dd("  paramTypes=", paramTypes);

        return canImplicitlyCastTo(call.argTypes, paramTypes);
    }
    Type getType(string str) {
        auto tokens = lexer.tokenise!true(str);
        auto nav = new Tokens(null, tokens);
        return module_.typeParser.parseForTemplate(nav, call);
    }
    auto buildRegexString(Token[] tokens, ref string[] proxyList) {
        //auto getRawSignature() {
        //    /// Parse tokens as possibly types with names and write them as types only.
        //    /// eg. turn this:
        //    ///     [A a,A b,A c] c
        //    /// into this:
        //    ///     "[A,A,A]"
        //    static class ProxyType : Type {
        //        int getEnum() const { return -1; }
        //        bool isKnown() { return true; }
        //        bool exactlyMatches(Type other) { return false; }
        //        bool canImplicitlyCastTo(Type other) { return false; }
        //        LLVMTypeRef getLLVMType() { return null; }
        //        override string toString() { return "__PROXY__"; }
        //    }
        //    Type proxy = new ProxyType;
        //
        //    foreach(ref t; tokens) {
        //        if(isProxy(t)) t.templateType = proxy;
        //    }
        //
        //    auto mod  = func.getModule;
        //    auto nav  = new Tokens(mod, tokens);
        //    Type type = mod.typeParser.parseForTemplate(nav, func);
        //
        //    if(type is null || type.isUnknown) return null;
        //
        //    return "%s".format(type);
        //}
        //
        //string rawSignature = getRawSignature();

        dd("--------------------------");
        dd("proxies:", proxies.toString);
        //dd("raw    :", rawSignature);
        dd("tokens :", tokens.toSimpleString);

        buf.clear();

        foreach(t; tokens[0..$-1]) {
            if(isProxy(t)) {
                buf.add(r"(.*)");
                proxyList ~= t.value;
            } else {
                buf.add(escapeRegex(toSimpleString(t)));
            }
        }
        import std.array : replace;
        string reg  = buf.toString();
        //string reg2 = escapeRegex(rawSignature).replace("__PROXY__", "(.*)");

        dd("regex  :", reg);

        return buf.toString();
    }
    /// Check arg tokens against call type.
    /// Assume:
    ///     tokens contains at least one template proxy
    void matchArg(int argIndex, Token[] tokens, Type callType) {
        string typeString  = "%s".format(callType);
        //string regexString = func.blueprint.getRegexStringForParam(argIndex);
        //string[] proxyList = func.blueprint.getProxyListForParam(argIndex);
        string[] proxyList;
        string regexString = buildRegexString(tokens, proxyList);
        auto rx            = regex(regexString);

        dd("tokens :", tokens.toSimpleString);
        dd("proxies:", proxyList);
        dd("regex  :", regexString);
        dd("type   :", typeString);
        dd("--------------------------");

        auto m = matchAll(typeString, rx);
        if(m.empty) {
            chat("\t\tNo match");
        } else {
            chat("\t\tMatch: %s", m.front[0]);
            int i = 0;
            foreach(r; m.front) {
                if(i>0) {
                    auto type = getType(r);
                    chat("\t\t[%s] %s = %s (type = %s)", i-1, proxyList[i-1], r, type);
                    addToHash(proxyList[i-1], type);
                }
                i++;
            }
        }
    }
}