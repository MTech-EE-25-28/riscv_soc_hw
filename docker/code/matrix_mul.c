
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>

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

    #define N                   (* (volatile uint8_t * ) 0x00000800)
    #define OUT                 (* (volatile     int * ) 0x00000804)
    #define CPU_DONE            (* (volatile uint8_t * ) 0x00000808)
    void _put_value(int32_t val) { }
    void _put_str(char *str) { }

#endif

int main () {
    int A[3][3], B[3][3], C[3][3] = {0};
    int i, j, k;

    A[0][0] =  1; A[0][1] = 2; A[0][2] = 3;
    A[1][0] = -1; A[1][1] = -10; A[1][2] = 11;
    A[2][0] = -232; A[2][1] = 42; A[2][2] = 32;

    B[0][0] = -19; B[0][1] = 51; B[0][2] = 1151;
    B[1][0] = 4; B[1][1] = 5; B[1][2] = 6;
    B[2][0] = 99; B[2][1] = 1; B[2][2] = -12;

    for (i=0; i<3; i++) {
        for (j=0; j<3; j++) {
            for (k=0; k<3; k++) {
                C[i][j] += A[i][k] * B[k][j];
            }
        }
    }

    for (i=0; i<3; i++) {
        for (j=0; j<3; j++) {
            OUT = C[i][j];
            _put_value(OUT);
        }
    }

    CPU_DONE = 1;
    // volatile asm ("ebreak");
    return 0;
}