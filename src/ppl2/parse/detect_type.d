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
    /// imp.Type   // returns 2
    /// type::type // returns 2
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
            found = possibleTuple(t, node);
        } else if(t.type==TT.LCURLY) {
            found = possibleFunctionType(t, node);
        } else {
            /// built-in type
            int p = g_builtinTypes.get(t.value, -1);
            if(p!=-1) {
                t.next;
                found = true;
            }
            /// Is it a Struct, Enum or Alias?
            if(!found) {
                auto ty = module_.typeFinder.findType(t.value, node);
                if(ty) {
                    t.next;
                    found = true;
                }

                /// Consume possible template parameters
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
            /// module alias? eg. imp.Type
            if(!found) {
                found = possibleModuleAlias(t, node);
            }
        }

        if(found) {

            if(t.type==TT.DBL_COLON) {
                //dd(module_.canonicalName, "-- inner type");
                /// Must be an inner type
                /// eg. type1:: type2 ::
                ///             ^^^^^^^^ repeat
                /// So far we have type1

                /// type2 must be one of: ( Enum | Struct | Struct<...> )

                while(t.type==TT.DBL_COLON) {
                    /// ::
                    t.skip(TT.DBL_COLON);

                    /// ( Enum | Struct | Struct<...> )
                    t.next;

                    if(t.type==TT.LANGLE) {
                        auto j = t.findEndOfBlock(TT.LANGLE);
                        if(j==-1) errorBadSyntax(module_, t, "Missing end >");
                        t.next(j+1);
                    }
                }
                //dd("-- end:", t.get);
            }

            while(true) {
                /// ptr depth
                while(t.type==TT.ASTERISK) {
                    t.next;
                }

                /// array declaration eg. int[3][1]
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
    ///     [type ...       Tuple
    ///     [expr ...       Not a type (LiteralArray or LiteralTuple)
    ///
    bool possibleTuple(Tokens t, ASTNode node) {
        assert(t.type==TT.LSQBRACKET);

        int end = t.findEndOfBlock(TT.LSQBRACKET);
        if(end==-1) return false;

        /// [
        t.next;

        /// First token must be a type
        int end2 = endOffset(t, node);
        if(end2==-1) return false;

        /// [ type

        /// constructor - this must be a LiteralArray or LiteralTuple
        if(t.peek(end2+1).type==TT.LBRACKET) return false;
        /// is expression
        if(t.peek(end2+1).value=="is") return false;
        /// dot expression
        if(t.peek(end2+1).type==TT.DOT) return false;

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
    /// imp.function       // not a type
    /// imp.enum           // must be a type
    /// imp.type<type>*    // must be a type because of the ptr
    /// imp.type           // might be a type. Need to make sire it is not followed by a static var or func
    ///          :: // followed by :: continue and expect another type
    ///          .  // followed by . must be a static var or func
    ///             // else it must be a type
    bool possibleModuleAlias(Tokens t, ASTNode node) {
        //if(module_.canonicalName=="tstructs::test_inner_structs2") dd("possibleModuleAlias", t.get, node.id);

        //if(t.peek(1).type==TT.DBL_COLON) { warn(t, "Deprecated ::"); }

        /// Look for imp .
        ///           0  1
        if(t.peek(1).type!=TT.DOT) return false;

        Import imp = findImportByAlias(t.value, node);
        //if(module_.canonicalName=="tstructs::test_inner_structs2") dd("imp=", imp);
        if(!imp) return false;

        /// ModuleAlias found. The imported symbol should be available.
        /// If it is not an Alias then it must be a function so we return false

        /// imp  .  ?
        ///  0   1  2
        if(!imp.getAlias(t.peek(2).value)) return false;

        /// We have a valid type

        /// imp  . type ?
        ///  0   1  2   3

        int i = 3;

        /// Consume any template params
        if(t.peek(i).type==TT.LANGLE) {
            i = t.findEndOfBlock(TT.LANGLE, i);
            if(i==-1) return false;
            i++;
        }

        /// We now have one of:
        ///   imp.Type
        ///   imp.Type<...>

        /// If the next type is :: it must be an inner type
        //if(t.peek(i).type==TT.DBL_COLON) {
        //    // handle this in endOffset func?
        //    /// Another type follows
        //    assert(false, "implement me");
        //}

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