# Constructors

```
struct S {
private
    int value
readonly
    bool flag
public
    new { // S* this
    }
    new { int value ->    // S* this
        this.value = value
    }
    new { bool flag, int value -> // S* this
        new(value)
        this.flag = flag
    }
}
```
###### Struct construction
```
S s
S s = S()   
```
- Alloca S
- Call S.new(s&)

```
S s = S(1)
S s = S(value:1)
```
- Alloca S
- Call S.new(&s, 1)

Note: May need to rewrite this in some way

```
S s = S(true,3)              // order is important
S s = S(value:3, flag:true)  // any order
```
- Alloca S
- Call S.new(&s, true, 3)

```
S* s
S* s = null
```
- Alloca S*
- s = null

```
S* s = S*()
```
- Alloca S*
- Call S.new(s)

```
S* s = S*(1)
S* s = S*(value:1)
```
- Alloca S*
- Call S.new(&s, 1)

```
S* s = S(true,3)
S* s = S(value:3, flag:true)
```
- Alloca S*
- Call S.new(&s, true, 3)

###### Anon structs
```
[int,bool] s
```
- Alloca [int,bool]
- Set to default values

```
[int,bool] s     = [1,true]
[int,bool] s     = [1]      // [1,false]
[int a,bool b] s = [a:1, b:true]
[int a,bool] s   = [a:1]    // [1,false]
```
- Alloca [int,bool]
- Set to 1,true
