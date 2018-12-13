module ppl2.known_bugs;

/*
- Const global variable not working:

    const VALUE = 10
    enum E { ONE = VALUE }


- Cryptic IR generation error produced:

    var c = A::ONE
    assert c.value = 1      // = instead of ==

- Assert this

    struct A {
        foo {
            assert this     // <--- error
        }
    }

- Infinite struct should not be allowed:

    struct A {
        A a
    }

- Missing return at end of function
    func {
        if(var a=0; true) return a

        // should be a return here
    }

- Should be able to determine type of null
    func {
        if(int a=0; true) return &a
        return null // <--- int*
    }

-   Determine type of null

    call(null)

-   config.enableOptimisation = false produces link errors

 */