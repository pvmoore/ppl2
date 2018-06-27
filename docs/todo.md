# Todo
## High Priority
- Check that call args match function
- Ambiguous overloads
- Literal structs
- Check access
- Multi level struct access

## Medium Priority
- Template structs
- Template functions
- Generate LLVM
- LiteralMap
- Compile time (meta) properties eg. #type, #length etc...
- If last arg of function is a closure then allow Groovy access
- More constant folding and dce (calls and functions)
- import c = core.c
    - c::memset(..)  // maybe re-use use Dot with a flag

## Think about
- #ptr #val are not very elegant. Maybe use & and *
- Maybe don't create new() functions for structs without any var initialisers.
  Define.requiresInitFunction() ?
- How to do closures (with captures)
- How to do named structs within named structs (this, super etc...) A.B

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
