
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>

// Read CPU cycle counter (64-bit)
uint64_t get_cycles() {
    uint32_t lo, hi;
    asm volatile (
        "rdcycle %0\n"
        "rdcycleh %1\n"
        : "=r"(lo), "=r"(hi)
    );
    return ((uint64_t)hi << 32) | lo;
}

// Read retired instruction counter (64-bit)
uint64_t get_instret() {
    uint32_t lo, hi;
    asm volatile (
        "rdinstret %0\n"
        "rdinstreth %1\n"
        : "=r"(lo), "=r"(hi)
    );
    return ((uint64_t)hi << 32) | lo;
}

// Read real-time clock (if implemented)
uint64_t get_time() {
    uint32_t lo, hi;
    asm volatile (
        "rdtime %0\n"
        "rdtimeh %1\n"
        : "=r"(lo), "=r"(hi)
    );
    return ((uint64_t)hi << 32) | lo;
}

int main() {
    get_cycles();
    get_time();
    get_instret();

    asm volatile ("ecall");
    asm volatile ("ebreak");

    return 0;
}