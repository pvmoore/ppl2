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

    bool isType(TokenNavigator t, ASTNode node) {
        return endOffset(t, node) != -1;
    }
    ///
    /// Return the offset of the end of the type.
    /// Return -1 if there is no type at current position.
    /// eg.
    /// int   // returns 0
    /// int** // returns 2
    ///
    int endOffset(TokenNavigator t, ASTNode node) {
        t.markPosition();
        int startOffset = t.index();
        bool found      = false;

        if(t.type==TT.LSQBRACKET && t.peek(1).type==TT.COLON) {
            found = possibleArrayType(t, node);
        } else if(t.type==TT.LSQBRACKET) {
            found = possibleAnonStruct(t, node);
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
                auto ty = findType(t.value, node);
                if(ty) {
                    t.next;
                    found = true;
                }
            }
            if(!found) {
                if(t.get.templateType) {
                    t.next;
                    found = true;
                }
            }
        }

        /// ptr depth
        if(found) {
            while(t.type==TT.ASTERISK) {
                t.next;
            }
        }

        int endOffset = t.index();
        t.resetToMark();
        if(!found) return -1;
        return endOffset - startOffset - 1;
    }
private:
    /// Starts with [:
    /// Could be an array type or array literal
    bool possibleArrayType(TokenNavigator t, ASTNode node) {
        assert(t.type==TT.LSQBRACKET);
        assert(t.peek(1).type==TT.COLON);

        int end = t.findEndOfBlock(TT.LSQBRACKET);
        if(end==-1) return false;

        t.next(2);

        /// First token must be a type
        if(!isType(t, node)) return false;

        t.next(end - 1);

        return true;
    }
    /// Starts with [
    /// Could be an AnonStruct or struct literal
    ///
    /// [int, int]
    /// [int id, int id]
    ///
    bool possibleAnonStruct(TokenNavigator t, ASTNode node) {
        assert(t.type==TT.LSQBRACKET);

        int end = t.findEndOfBlock(TT.LSQBRACKET);
        if(end==-1) return false;

        t.next;

        /// First token must be a type
        if(!isType(t, node)) return false;

        t.next(end);

        return true;
    }
    /// Starts with {
    /// Could be a FunctionType or literal function
    ///
    /// {void->void}
    /// {type,type->type}
    /// {type id, type id->type}
    ///
    bool possibleFunctionType(TokenNavigator t, ASTNode node) {
        assert(t.type==TT.LCURLY);

        int end = t.findEndOfBlock(TT.LCURLY);
        if(end==-1) return false;

        int scopeEnd = t.index() + end;

        t.next;

        /// Must have an arrow
        int arrow = t.findInCurrentScope(TT.RT_ARROW);
        if(arrow==-1) return false;

        /// Check the return type only
        t.next(arrow+1);

        int eot = endOffset(t, node);
        if(eot==-1) return false;

        /// Move to 1 past the end bracket
        t.next(eot + 2);

        return t.index() == scopeEnd + 1;
    }
}