
#include <stdint.h>
#include "trap_handler.h"
#include "memory_map.h"

int main() {
    // all peripheral register address are declared in memory_map.h
    TEST_LOC = 0; // explicitly zero before use — SRAM is undefined at power-on
    TIMER_OCMR = 255; // Set timer compare value to 255
    // Enable timer with interrupt
    TIMER_TCCR = 0x7; // Timer enable + PWM enable + IRQ enable

    while (1) {
        // Wait for interrupt to occur
        // The trap handler will set TEST_LOC to 1 when the timer interrupt is handled
        if (TEST_LOC == 1) {
            // Clear TEST_LOC for next interrupt
            TEST_LOC = 0;
            // Read current timer count
            uint32_t count = TIMER_TCNT;
            // For this test, write it back to a memory location
            TEST_LOC = count;
        }
    }
    return 0;
}