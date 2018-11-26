module ppl2.known_bugs;

/*
    1) Const global variable not working:

    const VALUE = 10
    enum E { ONE = VALUE }


    2) Cryptic IR generation error produced:

    var c = A::ONE
    assert c.value = 1      // = instead of ==

    3) Assert this

    struct A {
        foo {
            assert this     // <--- error
        }
    }

    4) Infinite struct should not be allowed:

    struct A {
        A a
    }


 */