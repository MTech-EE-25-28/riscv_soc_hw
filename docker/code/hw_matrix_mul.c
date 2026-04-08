
#include <stdint.h>
#include "memory_map.h"
// #include "trap_handler.h"

#if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // for host pc

    int OUT = 0, CPU_DONE = 0;

    #include <stdio.h>

    void _put_byte(char c) { putchar(c); }

    void _put_str(char *str) {
        while (*str) {
            _put_byte(*str++);
        }
    }

    void print_output(int32_t num) {
        if (num == 0) {
            putchar('0'); // if the number is 0, directly print '0'
            _put_byte('\n');
            return;
        }

        if (num < 0) {
            putchar('-'); // print the negative sign for negative numbers
            num = -num;   // make the number positive for easier processing
        }

        // convert the integer to a string
        char buffer[20]; // asSUMing a 32-bit integer, the maximum number of digits is 10 (plus sign and null terminator)
        uint8_t index = 0;

        while (num > 0) {
            buffer[index++] = '0' + num % 10; // convert the last digit to its character representation
            num /= 10;                        // move to the next digit
        }

        // print the characters in reverse order (from right to left)
        while (index > 0) { putchar(buffer[--index]); }
        _put_byte('\n');
    }

    void _put_value(int32_t val) { print_output(val); }

#else  // for the test device
    #define OUT                 (* (volatile    int * ) 0x00001004)
    #define CPU_DONE            (* (volatile int8_t * ) 0x00001008)
    void _put_value(int32_t val) { }
    void _put_str(char *str) { }

#endif

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
    for (int i = 0; i < 250000; i++);
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

// Placed in .data (SRAM) — startup copies from flash LMA to SRAM VMA.
// .rodata (ROM-only) is NOT accessible via lbu on this Harvard-arch CPU.
static char str_start[] = "Starting matrix multiplication...\n";
static char str_done[]  = "Matrix multiplication completed. Output:\n";

int main () {
    OUT = 0; CPU_DONE = 0;
    int i;

    gpio_init();
    uart_init();
    for (i = 0; i < 10000000; i++);
    uart_send_str(str_start);

    volatile uint32_t *mata_ptr = MM_MATA_PTR;
    volatile uint32_t *matb_ptr = MM_MATB_PTR;
    volatile uint32_t *matc_ptr = MM_MATC_PTR;

    for (i = 0; i < 16; i++) {
        mata_ptr[i] = i + 1;
        matb_ptr[i] = i + 1;
        matc_ptr[i] = 0; // clear output matrix
    }
    MM_CTSR = 0x00; // ensure control register is clear before starting
    MM_CTSR = 0x01; // start computation
    while (!(MM_CTSR & 0x2)); // wait for computation to complete
    for (i = 0; i < 10000000; i++);
    uart_send_str(str_done);
    for (i = 0; i < 16; i++) {
        int val = matc_ptr[i]; // single APB read; cache before uart calls corrupt APB state
        OUT = val;
        uart_send_int(val);
        uart_send_byte('\n');
        _put_value(val);
    }
    CPU_DONE = 1;
    while (1) {
        UART_UTDR = 'X';
        GPIO_GDAT ^= 0x0F; // Toggle GPIO pin 0-3
        for (volatile int j = 0; j < 10000000; j++); // approx 1s
        while (!(UART_USR0 & 0x4));
    }
    return 0;
}