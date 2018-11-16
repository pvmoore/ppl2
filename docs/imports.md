
##### Standard imports
- Imported modules are scanned for exports and parsed
- Can only import objects or functions. Not variables
- Can import at any scope
```
import ::= "import" package_name
```

```
import core::string

import c = core::c   // using alias
```
##### Handling foreign externs
```
extern putchar {int->int}       // c assumed
extern(c) puts {byte*->int}

extern(stdcall) MessageBox {char*,char*,int->void}

```
