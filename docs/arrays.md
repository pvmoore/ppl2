##### Static Arrays

###### Declaration
```
[int:3] a
```
###### Indexing an array
```
identifier ":" expression
a:0         // the 1st element
a:1         // the second element

b = 2
a:b         // the third element
a:call()    // where call returns 5, the sixth element
```
###### Properties
```
a#first    // the first element
a#last     // the last element
a#length   // the number of elements
a#type     // the element type

a#ptr      // ptr to the 1st element
a:0#ptr    // ptr to the 1st element
a:1#ptr    // ptr to the 2nd element

```
###### Literals
```
[int:3] a = [: 1,2,3]
var a     = [: 1,2,3]

Possibly [array: 1,2,3]
```
