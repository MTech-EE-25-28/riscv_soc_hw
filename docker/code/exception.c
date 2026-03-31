
#include <stdint.h>

extern void trap_handler();

#define UART_CTSR  (* (volatile int *)0x00002000)
#define UART_DATA  (* (volatile int *)0x00002004)

void __attribute__((interrupt("machine"))) trap_handler (void) {
    // Advance mepc past the trapping instruction so mret returns to the next instr
    uint32_t mepc, mcause;
    asm volatile ("csrr %0, mepc" : "=r"(mepc));
    mepc += 4;
    asm volatile ("csrw mepc, %0" : : "r"(mepc));
    asm volatile ("csrr %0, mcause" : "=r"(mcause)); // find exception cause
    UART_DATA = mcause; // write cause to UART
    UART_CTSR = 1; // enable UART, signal trap handled
}

int main() {
    // set trap handler address in mtvec
    asm("csrw mtvec, %0" :: "r"(trap_handler));
    asm(".word 0xdeadcafe");

    asm volatile ("ecall");
    asm volatile ("ebreak");

    return 0;
}