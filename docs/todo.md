# Todo  

- Add gc

- Change string to struct string { byte* ptr, int offset, int count } - this can then be used as a partial 
  string range

- Add object files in config to be added to the linker

- Parallelise compilation 

- If a var is never modified and no address taken, we can set it to const (Set resolver.setModified() also
  because we have changed the AST).

- use const LLVMValueRefs in gen_literals (ie. constString, constStruct, constNamedStruct and constArray

- Add module.getInternalRefs, getExternalRefs functions and use these instead of numRefs properties 
  
- Nested multiline comments

- Don't call requireFunction just to get the parameters for function resolution. 
  Use a different lighter-weight version eg. requireFunctionParams
  
- Ensure we remove static functions if they are not referenced. Aggressively remove functions etc if they are not referenced.  

- Attributes eg (* inline). (* expect true) (* notnull) (* memoize)
  or [[attribute]] [[expect 10]] [[min 0]] [[max 200]] [[profile]]

- #if #else #endif compile-time operations. 
  Needs to be able to parse compile-time boolean expressions
  
- Investigate co-routines (LLVM)

- #is_visible(identifier)
  Return true if identifier is visible from current position
  This can be used for testing
  
- Allow string identifiers for function names
```
    "i am a function" {}
    'i am a function {}
    `i am a function` {}
    "i am a function"()
    // not sure which quote to use ??
```
- Compose struct within another struct eg.
```
    struct A { doSomething {} }
    struct B {
        compose A a // think about this syntax
    }
    B b
    b.doSomething() 
```
- Idea: Allow single token comments 
  eg Map<#name String,int> map

- LiteralMap (requires core.map implementation)
- Check optimisation against opt. Use -debug-pass=Arguments to see which passes opt uses.
- Implement null checks when config.nullChecks==true. In each AST Dot, add an assert that the left hand side is not null. Possibly use LLVM isNull instruction.
- Is half data type worth using?
- Built-in vector types eg float4, int2 etc...
- More constant folding and dce (calls and functions)

- Allow block of raw LLVM IR eg.
```
IR { // or LLVM or similar
    %a = alloca i32
    ; etc...
}
```
## Template enhancements
- Allow template const parameter values eg
```
struct S = <A, int V=10> [ A[V] array ]
func     = <A, int V=10> { A[V] array -> }

var s = S<int,20>()
func<int,20>(array)
```
- Allow partially implicit template extraction eg
```
func = <A,B> { A a, B b ->}
func<int>(10,20) // 1 explicit param, 1 missing
```

## Think about
- Do we need to worry about alignment?
- How to do closures with captures
- Should we allow ptr arithmentic?

- Allow type inference here:
```
[int a, float b] r = getResult()
[var a, float b] r = getResult()
[a,b] r = getResult()
```

## Ref counting or garbage collection
- Garbage collection option
    - Look at https://github.com/orangeduck/tgc or similar
    - Need to provide some mechanism for memory ownership to be transferred to a different thread since this
      gc is per thread but this can be done with some lib routine in core.thread for example.
    - Change string to struct string { byte* ptr, int offset, int count } - this can then be used as a partial 
      string range and it also holds the original ptr which is required by the gc
- Some sort of unique ptr / memory owner
- Try to examine ptr lifetimes
```
ref<Object> r
ptr<Object> r
```
