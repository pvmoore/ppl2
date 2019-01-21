module ide.widgets.infoview;

import ide.internal;
import ppl2;

final class InfoView : TabWidget {
private:
    IDE ide;
    TokensView tokensView;
    ASTView astView;
    IRView irView;
    IRView optIRView;
    IRView linkedIRView;
    ASMView asmView;
public:
    this(IDE ide) {
        super("INFO-VIEW");
        this.ide = ide;

        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);

        tokensView   = new TokensView(ide);
        astView      = new ASTView(ide);
        irView       = new IRView("IR-VIEW", ide);
        optIRView    = new IRView("OPT-IR-VIEW", ide);
        linkedIRView = new IRView("LINKED-IR-VIEW", ide);
        asmView      = new ASMView("ASM-VIEW", ide);

        addTab(irView, "IR"d, null, false, null);
        addTab(optIRView, "OptIR"d, null, false, null);
        addTab(linkedIRView, "LinkedIR"d, null, false, null);
        addTab(asmView, "ASM"d, null, false, null);
        addTab(astView, "AST"d, null, false, null);
        addTab(tokensView, "Tokens"d, null, false, null);
    }
    TokensView getTokensView() { return tokensView; }
    ASTView getASTView()       { return astView; }
    IRView getIRView()         { return irView; }
    IRView getOptIRView()      { return optIRView; }
    IRView getLinkedIRView()   { return linkedIRView; }
    ASMView getASMView()       { return asmView; }
}

