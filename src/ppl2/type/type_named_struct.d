module ppl2.type.type_named_struct;

import ppl2.internal;

///
///
///
final class NamedStruct : ASTNode, Type {
private:
    string _uniqueName;
    LLVMTypeRef _llvmType;
public:
    string name;
    string moduleName;
    AnonStruct type;
    int numRefs;

/// Template stuff
    string[] templateParamNames;
    Token[] tokens;
    Set!string extractedTemplates;
    bool isTemplate() const { return templateParamNames.length > 0; }
/// end of template stuff

/// ASTNode interface
    override bool isResolved() { return isKnown; }
    override NodeID id() const { return NodeID.NAMED_STRUCT; }
    override Type getType() { return this; }

/// Type interface
    int getEnum() const { return Type.NAMED_STRUCT; }
    bool isKnown() { return type !is null; } //  && type.isKnown

    bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type
        if(!other.isNamedStruct) return false;

        auto right = other.getNamedStruct;

        return name==right.name;
    }
    bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        /// Now check the base type
        if(!other.isNamedStruct) return false;

        auto right = other.getNamedStruct;

        return name==right.name;
    }
    LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = struct_(getUniqueName());
        }
        return _llvmType;
    }
    string prettyString() {
        return getUniqueName();
    }
    //========================================================================================
    bool isAtModuleScope() {
        return parent.isModule;
    }
    string getUniqueName() {
        if(!_uniqueName) {
            _uniqueName = mangle(this);
        }
        return _uniqueName;
    }
    bool requiresExtraction(string name) {
        if(extractedTemplates is null) {
            extractedTemplates = new Set!string;
        }
        return !extractedTemplates.contains(name);
    }
    Token[] extract(ASTNode node, string name, Type[] templateArgs) {
        assert(extractedTemplates);
        extractedTemplates.add(name);

        if(templateArgs.length != templateParamNames.length) {
            throw new CompilerError(Err.TEMPLATE_INCORRECT_NUM_PARAMS, node,
                "Expecting %s template parameters".format(templateParamNames.length));
        }

        Token stringToken(string value) {
            auto t  = copyToken(tokens[0]);
            t.type  = TT.IDENTIFIER;
            t.value = value;
            return t;
        }
        Token typeToken(TT e) {
            auto t  = copyToken(tokens[0]);
            t.type  = e;
            t.value = "";
            return t;
        }
        int templateParamIndex(string param) {
            foreach(int i, n; templateParamNames) {
                if(n==param) return i;
            }
            return -1;
        }

        Token[] tokens = [
            stringToken("struct"),
            stringToken(name),
            typeToken(TT.EQUALS)
        ] ~ this.tokens.dup;

        foreach(ref tok; tokens) {
            if(tok.type==TT.IDENTIFIER) {
                int i = templateParamIndex(tok.value);
                if(i!=-1) {
                    tok.templateType = templateArgs[i];
                }
            }
        }
        return tokens;
    }
    //========================================================================================
    override string description() {
        return "NamedStruct[refs=%s] %s".format(numRefs, toString());
    }
    override string toString() {
        string s;
        if(isTemplate()) {
            s ~= "<" ~ templateParamNames.join(",") ~ "> ";
        }
        return "%s%s:%s%s".format(s, name, getUniqueName, isKnown ? "":"?");
    }
}