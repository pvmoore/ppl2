module ide.usecases.BuildCompleted;

import ide.internal;
import ppl2;

final class BuildCompleted {
private:
    IDE ide;
    ConsoleView console;
    EditorView editorView;
public:
    this(IDE ide) {
        this.ide        = ide;
        this.console    = ide.getConsole();
        this.editorView = ide.getEditorView();
    }
    void handle(BuildJob job) {
        console.logln("Build completed");

        auto b = job.getBuilder();

        if(b.getStatus()!=BuildState.Status.FINISHED_OK) {

            console.logln("%s".format(b.getStatus));

            auto compilerError     = cast(CompilerError)b.getException;
            auto unresolvedSymbols = cast(UnresolvedSymbols)b.getException;

            import ppl2.error;

            if(compilerError) {
                prettyErrorMsg(compilerError);
            } else if(unresolvedSymbols) {
                //displayUnresolved(b.allModules);
            } else {
                console.logln("%s", b.getException);
            }

            ide.getStatusLine().setBuildStatus("Build FAILED", b.getElapsedNanos());

            return;
        }

        ide.getStatusLine().setBuildStatus("Build OK", b.getElapsedNanos());

        b.dumpStats((string it)=>console.logln(it));

        /// Update the current state build if it was successful
        ide.setCurrentBuildState(b);

        /// Update visible info views
        auto infoView  = ide.getInfoView();
        auto editorTab = ide.getEditorView().getSelectedTab();
        if(editorTab) {
            auto m = b.getModule(editorTab.moduleCanonicalName);

            auto tokensView = infoView.getTokensView();
            auto astView    = infoView.getASTView();
            auto irView     = infoView.getIRView();
            auto optIrView  = infoView.getOptIRView();

            if(m) {
                tokensView.update(m.parser.getInitialTokens()[]);
                astView.update(m);
                irView.update(b.getUnoptimisedIR(editorTab.moduleCanonicalName));
                optIrView.update(b.getOptimisedIR(editorTab.moduleCanonicalName));
            } else {
                tokensView.clear();
                astView.clear();
                irView.update("");
                optIrView.update("");
            }
        }
    }
private:
    auto getContentLines(Module m) {
        auto tab = ide.getEditorView().getTabByCanonicalName(m.canonicalName);
        if(tab) {
            return tab.content.lines();
        }
        /// Load it
        return From!"std.stdio".File(m.fullPath, "rb")
                               .byLineCopy()
                               .map!(it=>convertTabsToSpaces(it).toUTF32)
                               .array;
    }
    void prettyErrorMsg(CompilerError e) {
        prettyErrorMsg(e.module_, e.line, e.column, e.msg);

        auto ambiguous = e.as!AmbiguousCall;
        if(ambiguous) {
            console.logln("\nLooking for:");
            console.logln("\n\t%s(%s)", ambiguous.name, ambiguous.argTypes.prettyString);

            console.logln("\n%s matches found:\n", ambiguous.overloadSet.length);

            foreach(callable; ambiguous.overloadSet) {
                auto params       = callable.getType().getFunctionType.paramTypes();
                string moduleName = callable.getModule.canonicalName;
                int line          = callable.getNode.line;
                console.logln("\t%s(%s) \t:: %s:%s", ambiguous.name, prettyString(params), moduleName, line);
            }
        }
    }
    void prettyErrorMsg(Module m, int line, int col, string msg) {
        assert(m);

        void showMessageWithoutLine() {
            console.logln("\nError: [%s] %s", m.fullPath, msg);
        }
        void showMessageWithLine() {
            console.logln("\nError: [%s Line %s:%s] %s", m.fullPath, line+1, col, msg);
        }

        if(line==-1 || col==-1) {
            showMessageWithoutLine();
            return;
        }

        auto lines = getContentLines(m);

        if(lines.length<=line) {
            showMessageWithoutLine();
            return;
        }

        showMessageWithLine();

        string spaces;
        for(int i=0; i<col; i++) { spaces ~= " "; }

        auto errorLineStr = lines[line];

        console.logln("%s|", spaces);
        console.logln("%sv", spaces);
        console.logln("%s", errorLineStr);
    }
}