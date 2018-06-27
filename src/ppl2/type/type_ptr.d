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
        assert(addPtrDepth >= 0);
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

        return (decorated is otherPtr.decorated) ||
               decorated.exactlyMatches(otherPtr.decorated);
    }
    bool canImplicitlyCastTo(Type other) {
        if(!prelimCanImplicitlyCastTo(this,other)) return false;

        auto otherPtr = other.as!PtrType;
        assert(otherPtr);

        return (decorated is otherPtr.decorated) ||
               decorated.canImplicitlyCastTo(otherPtr.decorated);
    }
    Expression defaultInitialiser() {
        return LiteralNull.makeConst(this);
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