
#include <stdint.h>
#include "trap_handler.h"
#include "memory_map.h"

int main() {
    // all peripheral register address are declared in memory_map.h
    TEST_LOC = 0; // explicitly zero before use — SRAM is undefined at power-on
    TIMER_OCMR = 255; // Set timer compare value to 255
    // Enable timer with interrupt
    TIMER_TCCR = 0x7; // Timer enable + PWM enable + IRQ enable
    GPIO_GDIR = 0x1; // Set GPIO pin 0 as output
    GPIO_GDAT = 0x41; // Set GPIO pin 0 high and pin 6 shouldn't be written
    while (1) {
        // Wait for interrupt to occur
        // The trap handler will set TEST_LOC to 108 when the timer interrupt is handled
        if (TEST_LOC == 108) {
            // Clear TEST_LOC for next interrupt
            TEST_LOC = 0;
            // Read current timer count
            uint32_t count = TIMER_TCNT;
            // For this test, write it back to a memory location
            TEST_LOC = count;
            GPIO_GDAT ^= 0x1; // Toggle GPIO pin 0
        }
    }
    return 0;
}