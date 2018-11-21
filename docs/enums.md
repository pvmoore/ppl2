
# Enums

enum     ::= "enum" [ ":" type ] "{" elements "}"
elements ::= element { "," element }
element  ::= identifier [ "=" expression ] 

Create a new type: Enum (with an element type)
-   Type is Enum, llvmType is element type
-   Only implicitly convertable to any other value of same Enum type

enum E : int {  // element type is int
    VAL,        // type is Enum, value is (0 int)
    VAL2 = 2,
    VAL3        // type is Enum, value is (3 int)
}
E is a zero sized struct.
No duplicate values allowed.
Must have at least one value.

This is basically a struct with only public static const members of struct type.
Nothing else is allowed. No constructors/functions etc...
The element values must be constant expressions of element type.

func { E e -> } // Accepts any member of E 

var a = E       // not valid
var b = E::VAL  // 0 as int; b is E

E c = E::VAL    // 

assert E::VAL is Enum