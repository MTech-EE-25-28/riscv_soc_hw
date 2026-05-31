
// blink test
#include <stdint.h>
#include "memory_map.h"

void GPIO_init() {
    GPIO_GDIR = 0x01; // Set GPIO pin 0 as output
    GPIO_GDAT = 0x00; // Set GPIO pin 0 low
}

void UART_init() {
    UART_UBRR = 0x1B; // Set baud rate divisor for 128000 baud
    UART_UCR1 = 0x07; // Enable UART, receiver, transmitter
}

int main () {
    volatile int i = 0;
    GPIO_init();
    UART_init();
    while (1) {
        // GPIO_GDAT = 0x01; // Toggle GPIO pin 0
        UART_UTDR = 'N';
        // while (!(UART_USR0 & 0x4));
        GPIO_GDAT ^= 0x01; // Toggle GPIO pin 0
        for (i = 0; i < 10000000; i++); // Delay
        while (!(UART_USR0 & 0x4));
    }
    return 0;
}