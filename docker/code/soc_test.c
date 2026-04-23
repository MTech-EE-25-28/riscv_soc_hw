
#include <stdint.h>
#include "trap_handler.h"
#include "memory_map.h"

int main() {
    // all peripheral register address are declared in memory_map.h
    TEST_LOC = 0; // explicitly zero before use — SRAM is undefined at power-on

    // timer setup
    TIMER_OCMR = 255; // Set timer compare value to 255
    TIMER_TCCR = 0x07; // Timer enable + PWM enable + IRQ enable
    // gpio setup
    GPIO_GDIR = 0x1; // Set GPIO pin 0 as output
    GPIO_GDAT = 0x41; // Set GPIO pin 0 high and pin 6 shouldn't be written
    // uart setup
    UART_UBRR = 0x04; // Set baud rate divisor for 115200 baud
    UART_UCR1 = 0x07; // Enable UART receiver, transmitter and RX interrupt
    UART_UTDR = 'X'; // Send 'X' character
    while (!(UART_USR0 & 0x4)); // SR bit[2] = TC (transmission complete), wait until set
    TEST_LOC = 111; // uart transmission should be done by now, set TEST_LOC to 111 to indicate UART test is done
    (void) TIMER_TIRQ; // Clear any pending timer interrupts by reading TIRQ
    while (1) {
        // Wait for interrupt to occur
        // The trap handler will set TEST_LOC to 108 when the timer interrupt is handled
        if (TEST_LOC == 108) {
            // Clear TEST_LOC for next interrupt
            TEST_LOC = 0;
            // Read current timer count
            uint32_t count = TIMER_TCNT;
            UART_UTDR = count; // Send timer count over UART
            while (!(UART_USR0 & 0x4)); // Wait till transmission is complete
            TEST_LOC = 789;
            GPIO_GDAT ^= 0x1; // Toggle GPIO pin 0
        }
    }
    return 0;
}