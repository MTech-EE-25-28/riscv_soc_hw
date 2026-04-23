
// trap handler for RISC-V SoC
#include <stdint.h>
#include "memory_map.h"

// Default Weak Handlers for Vectored Mode
// These provide safe defaults that can be overridden by user application.
// If not overridden, they simply return (doing nothing).
void __attribute__((weak, interrupt("machine"))) exception_handler(void) {
    // Default: advance mepc past faulting instruction and return
    uint32_t mepc;
    asm volatile ("csrr %0, mepc" : "=r"(mepc));
    mepc += 4;
    asm volatile ("csrw mepc, %0" : : "r"(mepc));
}

void __attribute__((weak, interrupt("machine"))) isr_spi(void) {
    // Default: do nothing (user should override to handle SPI interrupts)
}

void __attribute__((weak, interrupt("machine"))) isr_uart(void) {
    // Default: do nothing (user should override to handle UART interrupts)
}

void __attribute__((weak, interrupt("machine"))) isr_gpio(void) {
    // Default: do nothing (user should override to handle GPIO interrupts)
}

void __attribute__((weak, interrupt("machine"))) isr_timer(void) {
    // Default: do nothing (user should override to handle timer interrupts)
}

void __attribute__((weak, interrupt("machine"))) isr_mm(void) {
    // Default: do nothing (user should override to handle matrix multiplier interrupts)
}

// Direct Mode Trap Handler (example implementation)
void __attribute__((interrupt("machine"))) trap_handler (void) {
    uint32_t mepc, mcause;
    asm volatile ("csrr %0, mcause" : "=r"(mcause));

    if (mcause & 0x80000000) {
        // Interrupt
        // mepc already points to the interrupted instruction
        uint32_t id = mcause & 0x1F;
        // switch case needs jump table to be loaded into dmem
        if (id == 16) { // QSPI — read received byte to clear RX interrupt flag
            (void) QSPI_RXDATA_BUF;
            QSPI_CSR_ADDR = 0;
            TEST_LOC = 1;
        } else if (id == 17) { // UART — read received byte to drain RX FIFO
            (void) UART_URDR;
            // UART_UCR0 = 0;
            TEST_LOC = 1;
        } else if (id == 18) { // GPIO — read pin state to clear edge-detect flag
            (void) GPIO_GDAT;
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
        UART_UBRR = 0x1B;
        UART_UCR1 = 0x07;
        UART_UTDR = mcause;
    }
}