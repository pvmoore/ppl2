module ppl2.type.Pointer;

import ppl2.internal;

///
/// A view of a Type but with a different ptr depth.
///
final class Pointer : Type {
private:
    Type decorated; /// This should never be a Pointer
    int ptrDepth;

    this(Type d, int ptrDepth) {
        assert(!d.isPtr);
        assert(ptrDepth > 0);

        this.decorated  = d;
        this.ptrDepth   = ptrDepth;
    }
public:
    static Type of(Type t, int addPtrDepth) {
        if(t.isPtr) {
            addPtrDepth += t.getPtrDepth;
            assert(addPtrDepth >= 0);

            if(addPtrDepth > 0) {
                return new Pointer(t.as!Pointer.decoratedType, addPtrDepth);
            }

            /// Type is not a ptr any more
            return t.as!Pointer.decoratedType;
        }
        assert(addPtrDepth >= 0, "%s".format(addPtrDepth));
        if(addPtrDepth>0) {
            return new Pointer(t, addPtrDepth);
        }
        /// Just return the type
        return t;
    }
    //========================================================================================
/// Type interface
    int category() const { return decorated.category; }
    bool isKnown() { return decorated.isKnown; }

    bool exactlyMatches(Type other) {
        if(!prelimExactlyMatches(this, other)) return false;

        auto otherPtr = other.as!Pointer;
        assert(otherPtr);

        return decorated.exactlyMatches(otherPtr.decorated);
    }
    bool canImplicitlyCastTo(Type other) {
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        auto otherPtr = other.as!Pointer;
        assert(otherPtr);

        /// Can implicitly cast all pointers to void*
        if(other.isVoid) return true;

        return decorated.canImplicitlyCastTo(otherPtr.decorated);
    }
    LLVMTypeRef getLLVMType() {
        LLVMTypeRef t = decorated.getLLVMType();
        /// void* is not allowed so use i8* instead
        if(decorated.isVoid) {
            t = i8Type();
        }
        for(auto i=0;i<ptrDepth;i++) {
            t = pointerType(t);
        }
        return t;
    }
/// End of Type interface
    //========================================================================================
    int getPtrDepth() const { return ptrDepth; }
    Type decoratedType() { return decorated; }

    override string toString() {
        int p = ptrDepth;
        /// Functions have an implicit ptr
        if(decorated.isFunction) { p--;}

        return "%s%s".format(decorated, "*".repeat(p));
    }
    //override string toString() {
    //    string p = "*".repeat(getPtrDepth);
    //    return "%s%s".format(decorated, p);
    //}
}