# Todo

- Change function declaration syntax to 
```
funcname {

}
```

## High Priority
- Change array syntax to int[10] Also, allow int[] as a function arg somehow so that we can pass arbitrarily long arrays to functions. 
  This may involve adding an array [T*,long length] struct to hold these dynamic arrays
- Change struct/array literals to [int[]: 1,2,3], [Map: a=1,b=2], [List: 1,2]. 
  If no type is specified then assume array if types are implicitly the same or struct otherwise
- Attributes eg (* inline). (* expect true) (* notnull)
- Select expression:
```
var r = select(x) {
    1 { 10 }
    2 { 90+i }
    else { 0 }
}
```
## Medium Priority
- Other compile time meta properties eg. #type, #isptr, #isvalue, #init, #size etc... 
  (#size already implemented)
- import c = core.c
    - c::memset(..)  // maybe re-use Dot with a flag

## Low Priority
- LiteralMap (requires core.map implementation)
- Check optimisation against opt. Use -debug-pass=Arguments to see which passes opt uses.
- Implement null checks when config.nullChecks==true. In each AST Dot, add an assert that the left hand side is not null. Possibly use LLVM isNull instruction.
- Is half data type worth using?
- Built-in vector types eg float4, int2 etc...
- More constant folding and dce (calls and functions)
- Run DScanner to highlight unused functions etc
- Multi level struct access
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
