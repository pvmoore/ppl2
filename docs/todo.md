# Todo
## High Priority
- Check access when accessing struct members
- Operator overloading eg.
    - op: = { int index-> }
    - op+ = { A other -> }
- Attributes eg (* inline). (* expect true) (* notnull)

## Medium Priority
- Other compile time meta properties eg. #type, #length, #size etc... (#size already implemented)
- If last arg of function is a closure then allow Groovy access
- import c = core.c
    - c::memset(..)  // maybe re-use use Dot with a flag

## Low Priority
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
- Multi level struct access
## Template enhancements
- Allow template const parameter values eg
```
struct S = <A, int V=10> [ [:A V] array ]
func     = <A, int V=10> { [:A V] array -> }

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
- If we have any issues disambiguating struct/array literals then we could try syntax such as [array: 1,2,3] or [map: a=1,b=2]
## Low Priority
- Write AST as DOT (.gv) format so it can be viewed by using a dot viewer tool
    https://en.wikipedia.org/wiki/DOT_(graph_description_language)

- Allow type inference here:
```
[int a, float b] r = getResult()
[var a, float b] r = getResult()
[a,b] r = getResult()
```

- Do something with these
```
ref<Object> r
ptr<Object> r
```
