
#include <stdint.h>

int main() {
    uint32_t r1 = 1, r2 = 2;
    uint32_t out1 = 0, out2 = 0;

    // ---------- SAME rd and rs1 ----------
    asm volatile ("csrrw %0, mcycle, %0" : "+r"(r1));
    asm volatile ("csrrs %0, mcycle, %0" : "+r"(r1));
    asm volatile ("csrrc %0, mcycle, %0" : "+r"(r1));

    asm volatile ("csrrwi %0, mcycle, 1" : "=r"(out1));
    asm volatile ("csrrsi %0, mcycle, 1" : "=r"(out1));
    asm volatile ("csrrci %0, mcycle, 1" : "=r"(out1));

    // ---------- DIFFERENT rd and rs1 ----------
    asm volatile ("csrrw %0, mcycle, %1" : "=r"(out1) : "r"(r2));
    asm volatile ("csrrs %0, mcycle, %1" : "=r"(out1) : "r"(r2));
    asm volatile ("csrrc %0, mcycle, %1" : "=r"(out1) : "r"(r2));

    asm volatile ("csrrwi %0, mcycle, 2" : "=r"(out2));
    asm volatile ("csrrsi %0, mcycle, 2" : "=r"(out2));
    asm volatile ("csrrci %0, mcycle, 2" : "=r"(out2));

    // Trap instructions (optional for debug)
    asm volatile ("ecall");
    asm volatile ("ebreak");

    return 0;
}