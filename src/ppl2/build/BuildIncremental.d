module ppl2.build.BuildIncremental;
///
/// Handle incrementally building modules.
///
import ppl2.internal;

final class BuildIncremental : BuildState {
private:

public:
    this(LLVMWrapper llvmWrapper, Config config) {
        super(llvmWrapper, config);
    }
}