
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>

#if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // for host pc

    int N = 5, OUT = 0, CPU_DONE = 1;

    #include <stdio.h>

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

    void _put_value(uint8_t val) { print_output(val); }

#else  // for the test device

    #define N                   (* (volatile uint8_t * ) 0x00000800)
    #define OUT                 (* (volatile     int * ) 0x00000804)
    #define CPU_DONE            (* (volatile uint8_t * ) 0x00000808)
    void _put_value(uint8_t val) { }
    void _put_str(char *str) { }

#endif

/* Factorial Function*/
void factorial(int n) {
    int i;
    for (i = 2; i <= n; i++) {
        OUT *= i;
    }
}

// main function
int main() {
    // not sure why function with return doesn't work
    factorial(N);
    _put_value(OUT);
    CPU_DONE = 1;
    return 0;
}