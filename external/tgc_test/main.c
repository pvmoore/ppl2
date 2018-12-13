
#include "../tgc/tgc.h"

#include "stdio.h"

static tgc_t gc;

static void callback(void* p) {
    printf("Destroyed mem %llu\n", (size_t)p);
}

static void example_function() {
    void* memory = tgc_alloc(&gc, 1024);

    printf("ptr:%llu, size:%llu, flags:%u\n", (size_t)memory, tgc_get_size(&gc, memory), tgc_get_flags(&gc, memory));

    memory = tgc_realloc(&gc, memory, 2048);

    printf("ptr:%llu, size:%llu, flags:%u\n", (size_t)memory, tgc_get_size(&gc, memory), tgc_get_flags(&gc, memory));

    void* m2 = tgc_alloc_opt(&gc, 1000, 0, callback);

    printf("Alloced mem %llu\n", (size_t)m2);

    printf("hello\n");

    tgc_free(&gc, memory);
}

void main(int argc, char **argv) {
    printf("Testing tgc\n");

    tgc_start(&gc, &argc);

    example_function();

    tgc_stop(&gc);

    printf("Main thread finished\n");
    getchar();
}