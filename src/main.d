module main;
/**
 *	Here is an online LLVM demo page:
 *		http://ellcc.org/?page_id=340
 */
import ppl2.ppl2;

void main(string[] argv) {

    auto mainFile = "test/./test.p2";

    auto ppl2 = new PPL2;
    ppl2.setProject(mainFile);
    ppl2.build();

}


