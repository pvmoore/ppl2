##### Function declarations

- Use the curly bracket syntax

```
func_decl ::= "{" func_args "->" type "}
func_args ::= "" | type_list
type_list ::= { type [ name ] "," } type [ name ]
```
###### Declarations
```
{->}                // {inferred->inferred}
{->void}            // {inferred->void}
{void->}            // {void->inferred}
{var->var}          // {inferred->inferred}
{void->void}    
{int a, bool->bool}
{bool, int->void}
```
###### Definitions
```
{int,int->bool} f = { int t, int i-> return true }
{int,int->bool} f = { t, i -> return true }
f2 { int t, int i -> return true }  // {int,int->bool} inferred
```
###### Inline function blocks
```
a { int a -> return 0 }       // {int->int}
b {}                          // {void->void}
doSomething({a -> return a })   // {?->?}   // type of a needs to be resolved
doSomething() { a->
    return a
}   // groovy style
```
##### Function calls
```
doSomething()      // call no arg function
doSomething(10)    // call func that takes an int

```
