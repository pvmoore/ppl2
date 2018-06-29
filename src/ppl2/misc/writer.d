module ppl2.misc.writer;

import ppl2.internal;

void writeLL(Module m) {
    string path = getConfig().targetPath ~ "ir/";
    m.llvmValue.writeToFileLL(path ~ m.canonicalName ~ ".ll");
}
