module ppl2.resolve.resolve_module;

import ppl2.internal;

final class ModuleResolver {
private:
    AssertResolver assertResolver;
    AsResolver asResolver;
    BinaryResolver binaryResolver;
    BuiltinFuncResolver builtinFuncResolver;
    CallResolver callResolver;
    EnumResolver enumResolver;
    IfResolver ifResolver;
    IsResolver isResolver;
    SelectResolver selectResolver;
    LiteralResolver literalResolver;
    IndexResolver indexResolver;
    UnaryResolver unaryResolver;
    VariableResolver variableResolver;

    StopWatch watch;
    Array!Callable overloadSet;
    bool addedModuleScopeElements;
    bool modified;
    Set!ASTNode unresolved;
    bool stalemate = false;
public:
    Module module_;
    IdentifierResolver identifierResolver;

    ulong getElapsedNanos()        { return watch.peek().total!"nsecs"; }
    ASTNode[] getUnresolvedNodes() { return unresolved.values; }
    bool isModified()              { return modified; }
    bool isStalemate()             { return stalemate; }

    this(Module module_) {
        this.module_             = module_;
        this.assertResolver      = new AssertResolver(this, module_);
        this.asResolver          = new AsResolver(this, module_);
        this.binaryResolver      = new BinaryResolver(this, module_);
        this.builtinFuncResolver = new BuiltinFuncResolver(this, module_);
        this.callResolver        = new CallResolver(this, module_);
        this.identifierResolver  = new IdentifierResolver(this, module_);
        this.enumResolver        = new EnumResolver(this, module_);
        this.indexResolver       = new IndexResolver(this, module_);
        this.ifResolver          = new IfResolver(this, module_);
        this.isResolver          = new IsResolver(this, module_);
        this.selectResolver      = new SelectResolver(this, module_);
        this.literalResolver     = new LiteralResolver(this, module_);
        this.unaryResolver       = new UnaryResolver(this, module_);
        this.variableResolver    = new VariableResolver(this, module_);
        this.unresolved          = new Set!ASTNode;
        this.overloadSet         = new Array!Callable;
    }
    void clearState() {
        watch.reset();
        unresolved.clear();
        overloadSet.clear();
        addedModuleScopeElements = false;
    }
    void setModified() {
        this.modified = true;
    }

    ///
    /// Pass through any unresolved nodes and try to resolve them.   
    /// Return true if all nodes and aliases are resolved and no modifications occurred.
    ///
    bool resolve(bool isStalemate) {
        watch.start();
        this.modified  = false;
        this.stalemate = isStalemate;

        collectModuleScopeElements();

        unresolved.clear();

        foreach(r; module_.getCopyOfActiveRoots()) {
            recursiveVisit(r);
        }

        watch.stop();
        return unresolved.length==0 && modified==false;
    }
    void resolveFunction(string funcName) {
        watch.start();
        log("Resolving %s func '%s'", module_, funcName);

        /// Visit all functions at module scope with the right name
        foreach(n; module_.children) {
            auto f = cast(Function)n;
            if(f && f.name==funcName) {
                log("\t  Adding Function root %s", f);
                module_.addActiveRoot(f);

                /// Don't add reference here. Add it once we have filtered possible
                /// overload sets down to the one we are going to use.
            }
        }
        watch.stop();
    }
    void resolveAliasEnumOrStruct(string AliasName) {
        watch.start();
        log("Resolving %s Alias|enum|struct '%s'", module_, AliasName);

        module_.recurse!Type((it) {
            auto ns = it.as!NamedStruct;
            auto en = it.as!Enum;
            auto al = it.as!Alias;

            if(ns) {
                if(ns.name==AliasName) {
                    if(ns.parent.isModule) {
                        log("\t  Adding NamedStruct root %s", it);
                    }
                    module_.addActiveRoot(ns);
                    ns.numRefs++;
                }
            } else if(en) {
                if(en.name==AliasName) {
                    if(en.parent.isModule) {
                        log("\t  Adding Enum root %s", en);
                    }
                    module_.addActiveRoot(en);
                    en.numRefs++;
                }
            } else if(al) {
                if(al.name==AliasName) {
                    if(al.parent.isModule) {
                        log("\t  Adding Alias root %s", al);
                    }
                    module_.addActiveRoot(al);
                    al.numRefs++;

                    /// Could be a chain of Aliases in different modules
                    if(al.isImport) {
                        module_.buildState.aliasEnumOrStructRequired(al.moduleName, al.name);
                    }
                }
            }
        });

        watch.stop();
    }
    //=====================================================================================
    void visit(AddressOf n) {
        if(n.expr.id==NodeID.VALUE_OF) {
            auto valueof = n.expr.as!ValueOf;
            auto child   = valueof.expr;
            fold(n, child);
            return;
        }
    }
    void visit(Alias n) {
        if(n.cat==Alias.Category.TYPEOF_EXPR) {
            if(n.first.isResolved) {
                n.type = n.first.getType;
                n.cat  = Alias.Category.STANDARD;
            }
        } else {
            resolveAlias(n, n.type);
        }
    }
    void visit(AnonStruct n) {

    }
    void visit(ArrayType n) {
        resolveAlias(n, n.subtype);
    }
    void visit(As n) {
        asResolver.resolve(n);
    }
    void visit(Assert n) {
        assertResolver.resolve(n);
    }
    void visit(Binary n) {
        binaryResolver.resolve(n);
    }
    void visit(Break n) {
        if(!n.isResolved) {
            n.loop = n.getAncestor!Loop;
            if(n.loop is null) {
                module_.addError(n, "Break statement must be inside a loop", true);
            }
        }
    }
    void visit(BuiltinFunc n) {
        builtinFuncResolver.resolve(n);
    }
    void visit(Call n) {
        callResolver.resolve(n);
    }
    void visit(Calloc n) {
        resolveAlias(n, n.valueType);
    }
    void visit(Case n) {

    }
    void visit(Closure n) {

    }
    void visit(Composite n) {
        final switch(n.usage) with(Composite.Usage) {
            case STANDARD:
                /// Can be removed if empty
                /// Can be replaced if contains single child
                if(n.numChildren==0) {
                    n.detach();
                    modified = true;
                } else if(n.numChildren==1) {
                    auto child = n.first();
                    fold(n, child);
                }
                break;
            case PERMANENT:
                /// Never remove or replace
                break;
            case PLACEHOLDER:
                /// Never remove
                /// Can be replaced if contains single child
                if(n.numChildren==1) {
                    auto child = n.first();
                    fold(n, child);
                }
                break;
        }
    }
    void visit(Continue n) {
        if(!n.isResolved) {
            n.loop = n.getAncestor!Loop;
            if(n.loop is null) {
                module_.addError(n, "Continue statement must be inside a loop", true);
            }
        }
    }
    void visit(Constructor n) {
        resolveAlias(n, n.type);
    }
    void visit(Dot n) {
        auto lt      = n.leftType();
        auto rt      = n.rightType();
        auto builder = module_.builder(n);

        /// Rewrite Enum::A where A is also a type declared elsewhere
        //if(lt.isEnum && n.right().isTypeExpr) {
        //    auto texpr = n.right().as!TypeExpr;
        //    if(texpr.isResolved) {
        //        auto id = builder.identifier(texpr.toString());
        //        fold(n.right(), id);
        //        return ;
        //    }
        //}
    }
    void visit(Enum n) {
        enumResolver.resolve(n);
    }
    void visit(EnumMember n) {

    }
    void visit(EnumMemberValue n) {

    }
    void visit(ExpressionRef n) {

    }
    void visit(Function n) {

    }
    void visit(FunctionType n) {

    }
    void visit(Identifier n) {
        identifierResolver.resolve(n);
    }
    void visit(If n) {
        ifResolver.resolve(n);
    }
    void visit(Import n) {

    }
    void visit(Index n) {
        indexResolver.resolve(n);
    }
    void visit(Initialiser n) {
        n.resolve();
    }
    void visit(Is n) {
        isResolver.resolve(n);
    }
    void visit(LiteralArray n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralExpressionList n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralFunction n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralMap n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralNull n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralNumber n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralString n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralStruct n) {
        literalResolver.resolve(n);
    }
    void visit(Loop n) {

    }
    void visit(Module n) {

    }
    void visit(ModuleAlias n) {

    }
    void visit(NamedStruct n) {

    }
    void visit(Parameters n) {

    }
    void visit(Parenthesis n) {
        assert(n.numChildren==1);

        /// We don't need any Parentheses any more
        fold(n, n.expr());
    }
    void visit(Return n) {

    }
    void visit(Select n) {
        selectResolver.resolve(n);
    }
    void visit(TypeExpr n) {
        resolveAlias(n, n.type);
    }
    void visit(Unary n) {
        unaryResolver.resolve(n);
    }
    void visit(ValueOf n) {
        if(n.expr.id==NodeID.ADDRESS_OF) {
            auto addrof = n.expr.as!AddressOf;
            auto child  = addrof.expr;
            fold(n, child);
            return;
        }
    }
    void visit(Variable n) {
        variableResolver.resolve(n);
    }
    //==========================================================================
    void writeAST() {
        if(!module_.config.writeAST) return;

        //dd("DUMP MODULE", module_);

        auto f = new FileLogger(module_.config.targetPath~"ast/" ~ module_.fileName~".ast");
        scope(exit) f.close();

        module_.dump(f);

        f.log("==============================================");
        f.log("======================== Unresolved Nodes (%s)", unresolved.length);

        foreach (i, n; unresolved.values) {
            f.log("\t[%s] Line %s %s", i, n.line, n);
        }
        f.log("==============================================");
    }
    void fold(ASTNode replaceMe, ASTNode withMe) {
        auto p = replaceMe.parent;
        p.replaceChild(replaceMe, withMe);
        modified = true;

        /// Ensure active roots remain valid
        module_.addActiveRoot(withMe);
    }
    ///
    /// If type is a Alias then we need to resolve it
    ///
    void resolveAlias(ASTNode node, ref Type type) {
        if(!type.isAlias) return;

        auto def = type.getAlias;

        /// Handle import
        if(def.isImport) {
            auto m = module_.buildState.getOrCreateModule(def.moduleName);
            if(m.isParsed) {
                auto externDef = m.getAlias(def.name);
                if(externDef) {
                    /// Switch to the external Alias
                    def  = externDef;
                    type = PtrType.of(externDef, type.getPtrDepth);
                } else {
                    auto ns = m.getNamedStruct(def.name);
                    if(ns) {
                        /// Alias is resolved
                        type = PtrType.of(ns, type.getPtrDepth);
                        return;
                    }
                    module_.addError(module_, "Import %s not found in module %s".format(def.name, def.moduleName), true);
                    return;
                }
            } else {
                /// Come back when m is parsed
                return;
            }
        }

        /// Handle template proxy Alias
        if(def.isTemplateProxy) {

            /// Ensure template params are resolved
            foreach(ref t; def.templateProxyParams) {
                resolveAlias(node, t);
            }

            /// Resolve until we have the NamedStruct
            if(def.templateProxyType.isAlias) {
                resolveAlias(node, def.templateProxyType);
            }
            if(!def.templateProxyType.isNamedStruct) {
                unresolved.add(def);
                return;
            }

            /// We now have a NamedStruct to work with
            if(def.templateProxyParams.areKnown) {
                auto ns            = def.templateProxyType.getNamedStruct;
                string mangledName = ns.getUniqueName ~ "<" ~ module_.buildState.mangler.mangle(def.templateProxyParams) ~ ">";

                auto t = module_.typeFinder.findType(mangledName, ns);
                if(t) {
                    assert(t.isNamedStruct);
                    type = PtrType.of(t, type.getPtrDepth);
                    t.getNamedStruct.numRefs++;
                } else {
                    /// Extract the template
                    auto structModule = module_.buildState.getOrCreateModule(ns.moduleName);
                    structModule.templates.extract(ns, node, mangledName, def.templateProxyParams);

                    unresolved.add(def);
                }
            }
            return;
        }

        if(def.type.isKnown || def.type.isAlias) {
            /// Switch to the Aliasd type
            type = PtrType.of(def.type, type.getPtrDepth);
        } else {
            unresolved.add(def);
        }
    }
//==========================================================================
private:
    ///
    /// If this is the first time we have looked at this module then add           
    /// all module level variables to the list of roots to resolve
    ///
    void collectModuleScopeElements() {
        if(!addedModuleScopeElements && module_.isParsed) {
            addedModuleScopeElements = true;

            foreach(n; module_.getVariables()) {
                module_.addActiveRoot(n);
            }
        }
    }
    bool isAttached(ASTNode n) {
        if(n.parent is null) return false;
        if(n.parent.isModule) return true;
        return isAttached(n.parent);
    }
    void recursiveVisit(ASTNode m) {

        if(!isAttached(m)) return;

        if(m.id==NodeID.NAMED_STRUCT) {
            if(m.as!NamedStruct.isTemplateBlueprint) return;
        } else if(m.isFunction) {
            auto f = m.as!Function;
            if(f.isTemplateBlueprint) return;
            if(f.isImport) return;
        } else if(m.isAlias) {
            auto d = m.as!Alias;
            if(d.cat==Alias.Category.TYPEOF_EXPR) {

            } else {
                if(!d.type.isAlias) return;
            }
        }

        //dd("  resolve", typeid(m), "nid:", m.nid, module_.canonicalName, "line:", m.line+1);
        /// Resolve this node
        m.visit!ModuleResolver(this);

        if(!isAttached(m)) return;

        if(!m.isResolved) {
            unresolved.add(m);
        }

        /// Visit children
        foreach(n; m.children[].dup) {
            recursiveVisit(n);
        }
    }
}