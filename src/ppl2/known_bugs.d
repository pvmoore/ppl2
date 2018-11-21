module ppl2.known_bugs;

/*
    1) Const global variable not working:

    const VALUE = 10
    enum E { ONE = VALUE }


    2) Cryptic IR generation error produced:

    var c = A::ONE
    assert c.value = 1      // = instead of ==






 */