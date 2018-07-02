module ppl2.target;

import ppl2.internal;
///
/// Call or identifier target.
///
final class Target {
private:
    enum TargetType { NOTSET, FUNC, VAR, STRUCTVAR, STRUCTFUNC }

    Module module_;
    TargetType ttype;
    Variable var;
    Function func;
    int memberIndex;
public:
    bool isSet = false;
    Module targetModule;

    this(Module module_) {
        this.module_ = module_;
    }

    void set(Variable v) {
        assert(v, "Variable should not be null");
        assert(!isSet);
        this.isSet        = true;
        this.ttype        = TargetType.VAR;
        this.var          = v;
        this.targetModule = v.getModule;
        assert(targetModule);
        addRef();
    }
    void set(Function f) {
        assert(f, "Function should not be null");
        assert(!isSet);
        this.isSet        = true;
        this.ttype        = TargetType.FUNC;
        this.func         = f;
        this.targetModule = f.getModule;
        assert(targetModule);
        addRef();
    }
    /// Struct member variable (could also be a func variable)
    void set(Variable v, int memberIndex) {
        assert(v, "Variable should not be null");
        assert(!isSet);
        this.isSet        = true;
        this.ttype        = TargetType.STRUCTVAR;
        this.var          = v;
        this.targetModule = v.getModule;
        this.memberIndex  = memberIndex;
        assert(targetModule);
        addRef();
    }
    /// Struct member function
    void set(Function f, int memberIndex) {
        assert(f, "Function should not be null");
        assert(!isSet);
        this.isSet        = true;
        this.ttype        = TargetType.STRUCTFUNC;
        this.func         = f;
        this.targetModule = f.getModule;
        this.memberIndex  = memberIndex;
        assert(targetModule);
        addRef();
    }
    //===========================================================
    void dereference() {
        removeRef();
    }
    bool isResolved() {
        if(!isSet) return false;
        if(func) return func.getType.isKnown;
        if(var) return var.type.isKnown;
        return false;
    }
    Type getType() {
        if(func) return func.getType;
        if(var) return var.type;
        return TYPE_UNKNOWN;
    }
    int structMemberIndex() const { return memberIndex; }
    Variable getVariable() { return var; }
    Function getFunction() { return func; }
    Callable getCallable() {
        if(var) return var;
        return func;
    }
    bool isFunction() const { return func !is null; }
    bool isVariable() const { return var !is null; }
    bool isMemberVariable() const { return ttype==TargetType.STRUCTVAR; }
    bool isMemberFunction() const { return ttype==TargetType.STRUCTFUNC; }

    LLVMValueRef llvmValue() {
        if(isFunction) return func.llvmValue;
        if(isVariable) return var.llvmValue;
        return null;
    }
    Type returnType() {
        assert(isSet);
        assert(getType.isFunction);
        return getType.getFunctionType.returnType();
    }
    Type[] argTypes() {
        assert(isSet);
        assert(getType.isFunction);
        return getType.getFunctionType.argTypes();
    }
    override string toString() {
        string s = isSet && targetModule.nid != module_.nid ? targetModule.canonicalName~"." : "";
        s ~= var?var.name : func?func.name: "";
        string i = module_.nid == targetModule.nid ? "" : " (import)";
        return "Target: %s %s %s%s".format(ttype, s, getType, i);
    }
private:
    void addRef() {
        if(var) {
            var.numRefs++;
        } else {
            func.numRefs++;
        }
        if(targetModule.nid != module_.nid) targetModule.numRefs++;
    }
    void removeRef() {
        if(var) {
            var.numRefs--;
        } else {
            func.numRefs--;
        }
        if(targetModule.nid != module_.nid) targetModule.numRefs--;
    }
}