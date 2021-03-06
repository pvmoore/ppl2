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
        auto b = job.getBuilder();

        if(b.hasErrors()) {
            buildFailed(b);
        } else {
            buildSucceeded(b);
        }
    }
private:
    void buildSucceeded(BuildState b) {
        console.logln("OK");
        ide.getStatusLine().setBuildStatus("Build OK", b.getElapsedNanos());

        //b.dumpStats((string it)=>console.logln(it));

        updateViews(b);

        foreach(l; ide.getBuildListeners()) {
            l.buildSucceeded(b);
        }
    }
    void buildFailed(BuildState b) {

        updateViews(b);

        auto numErrors = b.getErrors().length;
        console.logln("Build failed with %s error%s:\n", numErrors, numErrors>1?"s":"");
        ide.getStatusLine().setBuildStatus("Build Failed", b.getElapsedNanos());

        if(numErrors==1) {
            console.logln("%s\n", b.getErrors()[0].toPrettyString());
        } else {
            foreach(i, err; b.getErrors()) {
                console.logln("[%s] %s", i+1, err.toConciseString());
            }
        }
    }
    void updateViews(BuildState b) {

        ide.setCurrentBuildState(b);

        /// Update visible info views
        auto infoView  = ide.getInfoView();
        auto editorTab = ide.getEditorView().getSelectedTab();
        if(editorTab) {
            auto m = b.getModule(editorTab.moduleCanonicalName);

            auto tokensView   = infoView.getTokensView();
            auto astView      = infoView.getASTView();
            auto irView       = infoView.getIRView();
            auto optIrView    = infoView.getOptIRView();
            auto linkedIrView = infoView.getLinkedIRView();
            auto asmView      = infoView.getASMView();

            if(m) {
                tokensView.update(m.parser.getInitialTokens()[]);
                astView.update(m);
                irView.update(b.getUnoptimisedIR(editorTab.moduleCanonicalName));
                optIrView.update(b.getOptimisedIR(editorTab.moduleCanonicalName));
                linkedIrView.update(b.getLinkedIR);
                asmView.update(b.getLinkedASM());
            } else {
                tokensView.clear();
                astView.clear();
                irView.update("");
                optIrView.update("");
            }
        }
    }
}