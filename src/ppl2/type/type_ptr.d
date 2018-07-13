module ppl2.type.type_ptr;

import ppl2.internal;

///
/// A view of a Type but with a different ptr depth.
///
final class PtrType : Type {
private:
    Type decorated; /// This should never be a PtrType
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
                return new PtrType(t.as!PtrType.decoratedType, addPtrDepth);
            }

            /// Type is not a ptr any more
            return t.as!PtrType.decoratedType;
        }
        assert(addPtrDepth >= 0, "%s".format(addPtrDepth));
        if(addPtrDepth>0) {
            return new PtrType(t, addPtrDepth);
        }
        /// Just return the type
        return t;
    }
    //========================================================================================
/// Type interface
    int getEnum() const { return decorated.getEnum; }
    bool isKnown() { return decorated.isKnown; }

    bool exactlyMatches(Type other) {
        if(!prelimExactlyMatches(this, other)) return false;

        auto otherPtr = other.as!PtrType;
        assert(otherPtr);

        return decorated.exactlyMatches(otherPtr.decorated);
    }
    bool canImplicitlyCastTo(Type other) {
        if(!prelimCanImplicitlyCastTo(this,other)) return false;
        auto otherPtr = other.as!PtrType;
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
    string prettyString() {
        return "%s%s".format(decorated.prettyString(), "*".repeat(ptrDepth));
    }
/// End of Type interface
    //========================================================================================
    int getPtrDepth() const { return ptrDepth; }
    Type decoratedType() { return decorated; }

    override string toString() {
        string p = "*".repeat(getPtrDepth);
        return "%s%s".format(decorated, p);
    }
}