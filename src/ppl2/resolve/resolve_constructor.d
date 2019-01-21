module ppl2.resolve.resolve_constructor;

import ppl2.internal;


final class ConstructorResolver {
private:
    Module module_;
    ModuleResolver resolver;
public:
    this(ModuleResolver resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Constructor n) {
        resolver.resolveAlias(n, n.type);

        if(n.isResolved) {
            assert(n.type.isStruct);

            auto struct_ = n.type.getStruct;

            /// If struct is a POD then rewrite call to individual property setters
            if(struct_.isPOD) {
                rewriteToPOD(n, struct_);
                return;
            }
        }
    }
private:
    void rewriteToPOD(Constructor n, Struct struct_) {
        /// Rewrite call args as identifier = value

        /// S(...)
        ///    Variable _temp
        ///    Dot
        ///       _temp
        ///       Call new
        ///          this*
        ///          args (optional) <--- move these
        ///    <-- to here
        ///    assign
        ///       dot
        ///          _temp
        ///          name
        ///       arg
        ///
        ///    _temp

        /// S*(...)
        ///    Variable _temp (type=S*)
        ///    _temp = calloc
        ///    Dot
        ///       _temp
        ///       Call new
        ///          _temp
        ///          args (optional) <--- move these
        ///    <-- to here
        ///    assign
        ///       dot
        ///          _temp
        ///          name
        ///       arg
        ///    _temp
        ///

        auto b = module_.builder(n);

        auto var  = n.first().as!Variable;
        Call call = n.getDescendent!Call;
        assert(var);
        assert(call);

        auto args  = call.args()[1..$].dup;
        auto names = call.paramNames ? call.paramNames[1..$] : null;
        if(args.length==0) return;

        string getMemberName(int index) {

            string badIndex() {
                module_.addError(n, "Too many initialiers. Found %s, expecting %s or fewer"
                    .format(args.length, struct_.numMemberVariables), true);
                return null;
            }

            if(names) {
                if(index>=names.length) {
                    return badIndex();
                }
                return names[index];
            } else {
                if(index>=struct_.numMemberVariables) {
                    return badIndex();
                }
                return struct_.getMemberVariable(index).name;
            }
        }

        //dd("!! args:", args, names);

        foreach(i, arg; args) {
            auto name = getMemberName(i.toInt);
            if(!name) return;

            //dd("!! name[", i, "]:", name);

            /// assign
            ///    dot
            ///       var.name
            ///       name
            ///    arg

            auto dot = b.dot(b.identifier(var), b.identifier(name));
            auto bin = b.binary(Operator.ASSIGN, dot, arg);

            n.insertAt(n.numChildren-1, bin);

        }

        //n.dumpToConsole();

        call.paramNames = null;
    }
}