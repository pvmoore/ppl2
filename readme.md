# PPL 2

Prototype Programming Language

## Syntax and Features

##### Types
```c
// Basic types
int n   = 0
bool b  = true
float c = 3.14
byte d  = 4

const int A = 10
    
// Inferred types
var m = n*2

// Arrays
int[2] b = [1,3]

// Tuples
[int a, float b] t
var a2 = t.a
var b2 = t.b
var a3 = t[0]

[int, float, bool] s = [1, 3.1, true]
var first = s[0]

// Function ptr
var ptr = { int a-> return a+1 }
assert ptr(10) == 11

// Structs
struct A {
    int a
    func {}
}
var s = A()
s.a = 1
s.func()

// Type alias
alias IntPtr = int*
alias MyFunc = {int->bool} 

int* p     = null
IntPtr ptr = p
assert ptr is int* 

```
##### Functions
```c
// Declare void function
func {}
// Call the function
func()

// Declare function with 2 parameters
func { int a, bool b ->
    return if(b) a else a+1
}
val result = func(10, true)

// Named arguments
func { int size, bool isRed -> }
func(isRed: true, size: 40)

// Call external C functions
extern putchar {int char -> int}

putchar('x')

// Template functions
func <T> { T a -> }
func<float>(1.3)

```
##### Structs
```c
struct MyStruct { 
    byte* basePtr
    int offset
readonly // can only be modified within this module
    int length
    static int counter = 0
public
    // Constructor 
    new { byte* ptr, int offset, int len ->
        this.basePtr = ptr
        this.offset  = offset
        this.length  = len
        
        // Built-in asserts
        assert #sizeof(MyStruct)==16   
    }
    // Instance function
    ptr { return basePtr+offset }
    
    // Static function
    static count { return counter }
    
    // Operator overloading
    operator[] { int index-> return ptr()[index] }
        
    operator== { MyStruct s -> 
        return length==s.length and memcmp(ptr(), s.ptr(), length) == 0 
    } 
    
    // Inner struct
    struct Struct2 {
        int a
    }
}
// Constructs value on the stack
var s = MyStruct(ptr,0,10)

// Constructs value on the heap
var s2 = MyStruct*(ptr,0,10)

// Construct using named arguments
var s3 = MyStruct(ptr: null, len: 0)

// Access the inner struct
MyStruct::Struct2 s

// Template structs

struct List<T> {
    T* array
    
    fun { T a-> }
}

// Create an instance of List where T is an int
var list = List<int>()
list.fun(3)

```

##### Enums

```c
enum A : byte {
    ONE,        // 0
    TWO = 5,    // 5
    THREE       // 6
    
}
A a    = A.TWO    
byte b = A.THREE.value  // 6

```
##### Control flow
```c
// IF
if(true) {

} else {

}
// If as an expression
var result = if(a>3) 5 else if(a<1) 6 else 9

// If with an init expression
if(var a = 1; a > 2) {
    print(a)
}
// is expressions
if(a is int) { }
if(a is not true) { }

// SELECT
select { // select the first expression that evaluates to true
    3<2  : print(1)
    a==b : print(2) 
    else : print(3)
}
// select with an init expression
select(val x = callfunc(); x) {
    1     : print(1)
    2,3,4 : print("2 to 4")
    else  : print("none")
}
// select as an expression
var r = select(x) {
    3    : a
    4    : b
    else : c
}

// LOOP
loop(var i; i>0; i+=1) {
    if(i>10) break
    if(i==2) continue
    println(i)
}

```
##### Imports
```c
// Import all public structs/enums and functions from a module
import mymodule

// Use imported function
func()

// Import all public structs/enums and functions from a module
// using a prefix 
import m = mymodule

// Use imported function (requires prefix)
m.func() 

```

## Requirements
- Dlang https://dlang.org/
- Dlang-common https://github.com/pvmoore/dlang-common
- Dlang-llvm https://github.com/pvmoore/dlang-llvm
- LLVM 7 .libs

