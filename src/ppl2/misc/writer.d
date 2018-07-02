module ppl2.misc.writer;

import ppl2.internal;

void writeLL(Module m, string subdir) {
    string path = getConfig().targetPath ~ subdir;
    m.llvmValue.writeToFileLL(path ~ m.canonicalName ~ ".ll");
}
