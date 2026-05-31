// Machine Timer Interrupt Test
// Demonstrates core-level machine timer interrupt (MTIP) usage
#include <stdint.h>
#include "trap_handler.h"
#include "memory_map.h"

// Helper macros for machine timer
static inline uint64_t rdcycle(void) {
    uint32_t lo, hi;
    asm volatile ("csrr %0, 0xB00" : "=r"(lo));  // mcyclel
    asm volatile ("csrr %0, 0xB80" : "=r"(hi));  // mcycleh
    return ((uint64_t)hi << 32) | lo;
}

static inline void set_mtimecmp(uint64_t value) {
    asm volatile ("csrw 0x7C0, %0" :: "r"((uint32_t)value));         // timecmpl
    asm volatile ("csrw 0x7C1, %0" :: "r"((uint32_t)(value >> 32))); // timecmph
}

static inline void enable_mtimer_interrupt(void) {
    uint32_t mask = 0x80;  // MTIE bit (bit 7)
    asm volatile ("csrs 0x304, %0" :: "r"(mask));  // Set MTIE in mie
}

static inline void disable_mtimer_interrupt(void) {
    uint32_t mask = 0x80;  // MTIE bit (bit 7)
    asm volatile ("csrc 0x304, %0" :: "r"(mask));  // Clear MTIE in mie
}

// Machine Timer ISR - called when cycle_counter >= timecmp
void __attribute__((interrupt("machine"))) isr_mtimer(void) {
    // Read current cycle count
    uint64_t now = rdcycle();

    // Set next timer interrupt for 10000 cycles from now
    set_mtimecmp(now + 10000);

    // Signal that timer fired
    TEST_LOC *= 2;
}

int main() {
    TEST_LOC = 1;

    // Enable machine-mode interrupts globally (MIE bit in mstatus)
    asm volatile ("csrsi mstatus, 0x8");

    // Enable machine timer interrupt (MTIE bit in mie)
    enable_mtimer_interrupt();

    // Get current cycle count
    uint64_t start = rdcycle();

    // Set timer to fire in 5000 cycles
    set_mtimecmp(start + 5000);

    asm volatile ("wfi"); // Wait for first interrupt
    TEST_LOC = 1;
    UART_UBRR = 0x04;
    UART_UCR1 = 0x07; // Enable UART receiver, transmitter and RX interrupt
    UART_UTDR = 'A'; // Send 'A' to indicate first interrupt handled
    while(!(UART_USR0 & 0x4)); // Wait until transmission is complete
    while (1);

    return 0;
}
