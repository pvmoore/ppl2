##### Named Structs and Anonymous Structs (Tuples)
```
struct S { int a }      // named struct
[int] b                 // anon struct 
```
###### Accessing struct members
```
struct S { int a, bool b }
S s
a = s.a
b = s.b

a = s[0]
b = s[1]
c = s[2] // static bounds error
```
###### Accessing anon struct members
```
[int,bool] s1
[int a, bool b] s2
a = s1[0]     // int
b = s1[1]     // bool

var expr = 0
c = s1[expr]    // a
a = s2.a
b = s2.b
```
###### Defining a struct with properties and functions
```
struct S {
private
    int a
    bool b
public
    float c = 1

    new { S* this ->
        // implicity returns this
    }

    f { int a -> // {S* this, int a}->bool
        this.a = a
        return true
    }
    {int->bool} f2 { int a ->
        return false
    }
}
```
###### Constructing a struct
```
S s     // S value. s properties set to default values
S* s    // null, a is an S value
a = S()
    // create S with default values
    // call S.new(this)        
b = S(a=2)
    // create new S with default values, set a=2
    // b is an S value

```
###### Literals
```
var s = [1,2,3] as struct           // [int,int,int]
var s = [1,2,3] as [byte,byte,byte] // [byte,byte,byte] 
[int,int,int] s = [1,2,3]           // [int,int,int]
```
