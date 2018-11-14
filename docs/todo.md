# Todo  

- enums
- Nested multiline comments
- Add module.getInternalRefs, getExternalRefs functions and use these instead of numRefs properties 

- Don't call requireFunction just to get the parameters for function resolution. Use a different lighter-weight
  version eg. requireFunctionParams
- Ensure we remove static funstions if they are not referenced. Aggressively remove functions etc if they are not referenced.  
- Attributes eg (* inline). (* expect true) (* notnull) or [[attribute]] [[expect 10]] [[min 0]] [[max 200]] [[profile]]
- Select expression:
```
var r = select(x) {
    1 { 10 }
    2 { 90+i }
    else { 0 }
}
```
- #if #else #endif compile-time operations. 
  Needs to be able to parse compile-time boolean expressions
- Investigate co-routines (LLVM)

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

- Other compile time meta properties eg. #type, #isptr, #isvalue, #init, #size etc... 
  (#size already implemented)
  Maybe do these as builtin funcs instead of properties

- LiteralMap (requires core.map implementation)
- Check optimisation against opt. Use -debug-pass=Arguments to see which passes opt uses.
- Implement null checks when config.nullChecks==true. In each AST Dot, add an assert that the left hand side is not null. Possibly use LLVM isNull instruction.
- Is half data type worth using?
- Built-in vector types eg float4, int2 etc...
- More constant folding and dce (calls and functions)
- Run DScanner to highlight unused functions etc
- Multi level struct access (maybe also add 'outer' keyword)
```
// assume they are always static
A::B ab = A::B()
a::B::a = 3
```
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
- How to do named structs within named structs (this, super etc...) A.B
- Should we allow ptr arithmentic?

- Allow type inference here:
```
[int a, float b] r = getResult()
[var a, float b] r = getResult()
[a,b] r = getResult()
```

- Do something with these ideas
```
ref<Object> r
ptr<Object> r
```
