
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>

#if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // for host pc

    #include <stdio.h>

    int N = 20, OUT = 0, CPU_DONE = 0;

    void _put_byte(char c) { putchar(c); }

    void _put_str(char *str) {
        while (*str) {
            _put_byte(*str++);
        }
    }

    void print_output(uint8_t num) {
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
        char buffer[20]; // assuming a 32-bit integer, the maximum number of digits is 10 (plus sign and null terminator)
        uint8_t index = 0;

        while (num > 0) {
            buffer[index++] = '0' + num % 10; // convert the last digit to its character representation
            num /= 10;                        // move to the next digit
        }

        // print the characters in reverse order (from right to left)
        while (index > 0) { putchar(buffer[--index]); }
        _put_byte('\n');
    }

    void _put_value(uint8_t val) { print_output(val); }

#else  // for the test device

    #define N                 (* (volatile uint8_t * ) 0x00000800)
    #define OUT               (* (volatile uint8_t * ) 0x00000804)
    #define CPU_DONE          (* (volatile uint8_t * ) 0x00000808)
    void _put_value(uint8_t val) { }
    void _put_str(char *str) { }

#endif

// main function
int main() {
    OUT = 0;

    // Convert seconds to hours:minutes:seconds
    uint32_t total_seconds = 3725; // 1 hour, 2 minutes, 5 seconds
    uint32_t hours = total_seconds / 3600;
    uint32_t remainder = total_seconds % 3600;
    uint32_t minutes = remainder / 60;
    uint32_t seconds = remainder % 60;

    _put_str("Time: ");
    _put_value(hours);
    _put_str(":");
    _put_value(minutes);
    _put_str(":");
    _put_value(seconds);
    _put_str("\n");
    OUT = hours; OUT = minutes; OUT = seconds;

    // Find GCD using Euclidean algorithm (iterative)
    uint32_t a = 48, b = 18;
    uint32_t orig_a = a, orig_b = b;
    while (b != 0) {
        uint32_t temp = b;
        b = a % b;
        a = temp;
    }
    _put_str("GCD of ");
    _put_value(orig_a);
    _put_str(" and ");
    _put_value(orig_b);
    _put_str(" = ");
    _put_value(a);
    _put_str("\n");
    OUT = orig_a; OUT = orig_b; OUT = a;

    CPU_DONE = 1;
    return 0;
}