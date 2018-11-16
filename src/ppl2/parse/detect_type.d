module ppl2.parse.detect_type;

import ppl2.internal;
///
///
///
final class TypeDetector {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
    }

    bool isType(Tokens t, ASTNode node, int offset = 0) {
        return endOffset(t, node, offset) != -1;
    }
    ///
    /// Return the offset of the end of the type.
    /// Return -1 if there is no type at current position.
    /// eg.
    /// int        // returns 0
    /// int**      // returns 2
    /// static int // returns 1
    /// imp::Type  // returns 2
    ///
    int endOffset(Tokens t, ASTNode node, int offset = 0) {
        t.markPosition();

        int startOffset = t.index();
        bool found      = false;

        t.next(offset);

        if("static"==t.value) t.next;

        if(t.value=="#typeof") {
            typeof_(t, node);
            found = true;
        } else if(t.type==TT.LSQBRACKET) {
            found = possibleArrayTypeOrAnonStruct(t, node);
        } else if(t.type==TT.LCURLY) {
            found = possibleFunctionType(t, node);
        } else {
            /// built-in type
            int p = g_builtinTypes.get(t.value, -1);
            if(p!=-1) {
                t.next;
                found = true;
            }
            /// Is it a NamedStruct or Define?
            if(!found) {
                auto ty = module_.typeFinder.findType(t.value, node);
                if(ty) {
                    t.next;
                    found = true;
                }

                /// Read possible template parameters
                if(t.type==TT.LANGLE) {
                    int eob = t.findEndOfBlock(TT.LANGLE);
                    t.next(eob + 1);
                }

            }
            /// Template type?
            if(!found) {
                if(t.get.templateType) {
                    t.next;
                    found = true;
                }
            }
            /// import alias? imp::Type
            if(!found) {
                found = possibleImportAlias(t, node);
            }
        }

        /// ptr depth
        if(found) {
            while(true) {
                while(t.type==TT.ASTERISK) {
                    t.next;
                }

                if(t.onSameLine && t.type==TT.LSQBRACKET) {
                    int end = t.findEndOfBlock(TT.LSQBRACKET);
                    t.next(end + 1);
                } else break;
            }
        }

        int endOffset = t.index();
        t.resetToMark();
        if(!found) return -1;
        return endOffset - startOffset - 1;
    }
private:
    /// Starts with '['
    /// Could be one of:
    ///     [type : expr]   ArrayType
    ///     [type ...       AnonStruct
    ///     [expr ...       Not a type (LiteralArray or LiteralStruct)
    ///
    bool possibleArrayTypeOrAnonStruct(Tokens t, ASTNode node) {
        assert(t.type==TT.LSQBRACKET);

        int end = t.findEndOfBlock(TT.LSQBRACKET);
        if(end==-1) return false;

        /// [
        t.next;

        /// First token must be a type
        int end2 = endOffset(t, node);
        if(end2==-1) return false;

        //if(!isType(t, node)) return false;

        /// constructor - this must be a LiteralArray or LiteralStruct
        if(t.peek(end2+1).type==TT.LBRACKET) return false;

        t.next(end);

        return true;
    }
    /// Starts with '{'
    /// Could be a FunctionType or LiteralFunction
    ///
    /// {void->void}
    /// {type,type->type}
    /// {type id, type id->type}
    ///
    bool possibleFunctionType(Tokens t, ASTNode node) {
        assert(t.type==TT.LCURLY);

        int end = t.findEndOfBlock(TT.LCURLY);
        if(end==-1) return false;

        int scopeEnd = t.index() + end;

        t.next;

        /// Must have an arrow
        int arrow = t.findInScope(TT.RT_ARROW);
        if(arrow==-1) return false;

        /// Check the return type only
        t.next(arrow+1);

        int eot = endOffset(t, node);
        if(eot==-1) return false;

        /// Move to 1 past the end bracket
        t.next(eot + 2);

        return t.index() == scopeEnd + 1;
    }
    /// imp::Type<int>*
    bool possibleImportAlias(Tokens t, ASTNode node) {

        if(t.peek(1).type!=TT.DBL_COLON) return false;

        Import imp = findImportByAlias(t.value, node);
        if(!imp) return false;

        if(!imp.getAlias(t.peek(2).value)) return false;

        int i = 3;

        if(t.peek(i).type==TT.LANGLE) {
            i = t.findEndOfBlock(TT.LANGLE, i);
            if(i==-1) return false;
            i++;
        }

        /// We now have:
        ///   'imp::Type' or
        ///   'imp::Type<...>'
        ///
        /// Since we don't currently support externally-accessible
        /// inner classes, if the next type is ::
        /// it must be one of:
        ///   imp::Type::staticvar
        ///   imp::Type::staticfunc(
        ///
        /// in which case this is not a type.

        if(t.peek(i).type==TT.DBL_COLON) return false;

        t.next(i);
        return true;
    }
    /// #typeof ( expr )
    void typeof_(Tokens t, ASTNode node) {
        /// #typeof
        t.next;

        /// (
        int eob = t.findEndOfBlock(TT.LBRACKET);
        t.next(eob);

        /// )
        t.skip(TT.RBRACKET);
    }
}