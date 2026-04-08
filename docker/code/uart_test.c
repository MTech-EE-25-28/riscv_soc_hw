
// uart test
#include <stdint.h>
#include "memory_map.h"

#if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // host stubs

void uart_init() { }
void uart_send_str(char *str) { _put_str(str); }
void uart_send_byte(char c) {  }
int uart_send_int(int num) {
    // print_output(num);
    return 0;
}

#else // hardware specific functions

void gpio_init () {
    GPIO_GDIR = 0x0F; // Set GPIO pin 0-3 as output
    GPIO_GDAT = 0x00; // Set GPIO pin 0-3 low
}

void uart_init() {
    UART_UBRR = 0x1B; // Set baud rate divisor: 50MHz / (27 * 16) = 115,740 ~= 115200 baud
    UART_UCR1 = 0x07; // Enable UART, receiver, transmitter
}

void uart_send_str(char *str) {
    while (*str) {
        // while (!(UART_USR0 & 0x2)); // Wait until TXE (transmit buffer empty) is set
        UART_UTDR = *str++; // Send the next character
        while (!(UART_USR0 & 0x4)); // Wait until TC (transmission complete) is set
    }
}

void uart_send_byte(char c) {
    for (volatile int i = 0; i < 250000; i++);
    UART_UTDR = c;
    while (!(UART_USR0 & 0x4)); // Wait until TC is set
}

int uart_send_int(int num) {
    if (num == 0) {
        uart_send_byte('0');
        return 1;
    }
    int neg = 0;
    if (num < 0) {
        uart_send_byte('-');
        num = -num;
        neg = 1;
    }
    char buffer[20];
    int index = 0;
    while (num > 0) {
        buffer[index++] = '0' + num % 10;
        num /= 10;
    }
    for (int i = index - 1; i >= 0; i--) {
        uart_send_byte(buffer[i]); // send directly — no rodata pointer
    }
    return index + neg;
}

// generate local bss
void *memset(void *dst, int val, unsigned int n) {
    unsigned char *p = (unsigned char *)dst;
    for (unsigned int i = 0; i < n; i++) {
        p[i] = (unsigned char)val;
    }
    return dst;
}

void *memcpy(void *dst, const void *src, unsigned int n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    for (unsigned int i = 0; i < n; i++) {
        d[i] = s[i];
    }
    return dst;
}

#endif

// static char str_start[] = "Starting matrix multiplication...\n";
// static char str_done[]  = "Matrix multiplication completed. Output:\n";

int main () {
    volatile int i = 0;
    gpio_init();
    uart_init();
    for (i = 0; i < 10000000; i++);
    char ch;
    for (ch = 'a'; ch <= 'z'; ch++) {
        uart_send_byte(ch);
    }

    while (1) {
        UART_UTDR = 'w';
        // while (!(UART_USR0 & 0x4));
        GPIO_GDAT ^= 0x0F; // Toggle GPIO pin 0
        for (i = 0; i < 5000000; i++); // Delay
        while (!(UART_USR0 & 0x4));
    }
    return 0;
}