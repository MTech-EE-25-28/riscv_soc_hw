
// trap handler for RISC-V SoC
#include <stdint.h>
#include "memory_map.h"
// for now it is in direct mode
void __attribute__((interrupt("machine"))) trap_handler (void) {
    uint32_t mepc, mcause;
    asm volatile ("csrr %0, mcause" : "=r"(mcause));

    if (mcause & 0x80000000) {
        // Interrupt
        // mepc already points to the interrupted instruction
        uint32_t id = mcause & 0x1F;
        // switch case needs jump table to be loaded into dmem
        if (id == 16) { // QSPI — read received byte to clear RX interrupt flag
            (void) QSPI_DATA;
            QSPI_STATUS = 0;
            TEST_LOC = 1;
        } else if (id == 17) { // UART — read received byte to drain RX FIFO
            (void) UART_DATA;
            UART_STATUS = 0;
            TEST_LOC = 1;
        } else if (id == 18) { // GPIO — read pin state to clear edge-detect flag
            (void) GPIO_DATA;
            TEST_LOC = 1;
        } else if (id == 19) { // Timer — acknowledge by clearing the timer interrupt flag
            // TIMER_CTRL = 0;
            TEST_LOC = 108;
        } else if (id == 20) { // Matrix Mul ignored
            TEST_LOC = 1;
        }

    } else {
        // Synchronous exception
        asm volatile ("csrr %0, mepc" : "=r"(mepc));
        mepc += 4; // put mepc on the next instruction
        asm volatile ("csrw mepc, %0" : : "r"(mepc));
        // Log cause to UART for debug visibility
        UART_DATA   = mcause;
        UART_STATUS = 1;
    }
}