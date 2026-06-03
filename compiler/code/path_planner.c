
/*
* This program computes the valid path from the start point to the end point.
*/

// #include <stdlib.h>
#include <stdint.h>
# define V 32
# define UCHAR_MAX 255

#if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // for host pc

    #include <stdio.h>
    #include <stdlib.h>
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

    void _put_value(uint8_t val) { }
    void _put_str(char *str) { }

#endif

/*
Functions Usage

instead of using printf() function for debugging,
use the below function calls to print a number, string or a newline

for newline: _put_byte('\n');
for string:  _put_str("your string here");
for number:  _put_value(your_number_here);

Examples:
        _put_value(START_POINT);
        _put_value(END_POINT);
        _put_str("Hello World!");
        _put_byte('\n');

*/

// Custom Functions

uint8_t get_bit(uint32_t *p, uint8_t bit){return (*p >> bit) & 0x1;};

void set(uint32_t *p, uint8_t bit){*p |= 1 << bit;}

void reverse_path(uint8_t *path, uint8_t idx){
    uint8_t temp;
    for(int i = 1; i <= idx/2; i++){
        temp = *(path + i);
        *(path + i) = *(path + idx - i);
        *(path + idx - i) = temp;
    }
}

uint8_t retracePath(uint8_t * parent, uint8_t j, uint8_t *path_planned) {
    uint8_t val = 1;
    while (*(parent + j) != UCHAR_MAX) {
        *(path_planned + val) = j;
        j = *(parent + j);
        val++;
    }
    return val;
}

// main function
int main(int argc, char const *argv[]) {

    #if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // for host pc

        const uint8_t START_POINT   = 4;
        const uint8_t END_POINT     = 18;
        uint8_t NODE_POINT          = 0;
        uint8_t CPU_DONE            = 0;

    #else
        // Address value of variables are updated for RISC-V Implementation
        #define START_POINT         (* (volatile uint8_t * ) 0x00001000)
        #define END_POINT           (* (volatile uint8_t * ) 0x00001001)
        #define NODE_POINT          (* (volatile uint8_t * ) 0x00001004)
        #define CPU_DONE            (* (volatile uint8_t * ) 0x00001008)

    #endif

    // array to store the planned path
    uint8_t path_planned[32];
    // index to keep track of the path_planned array
    uint8_t idx = 0;

    #if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // for host pc
        uint32_t graph[32], sptSet_val;
        uint8_t  dist[32], parent[32], min_val, min_index_val;
        uint32_t *sptSet    = &sptSet_val;
        uint8_t  *min       = &min_val;
        uint8_t  *min_index = &min_index_val;

        // Defining the graph for Linux // bit masking
        // node 0 is connected to 1, 6, 10
        // NODE No    31   27   23   19   15   11   7       0
        // graph[0] = 0000 0000 0000 0000 0000 0100 0100 0010
        // NODE No    31   27   23   19   15   11   7654 3210
        // graph[x] = 0001 0000 0000 0000 0000 1000 0000 0000
        graph[ 0] = 0x442;      graph[ 1] = 0x805;
        graph[ 2] = 0x3a;       graph[ 3] = 0x4;
        graph[ 4] = 0x4;        graph[ 5] = 0x4;
        graph[ 6] = 0x381;      graph[ 7] = 0x40;
        graph[ 8] = 0x40;       graph[ 9] = 0x40;
        graph[10] = 0x5000801;  graph[11] = 0x81402;
        graph[12] = 0x6800;     graph[13] = 0x1000;
        graph[14] = 0x19000;    graph[15] = 0x4000;
        graph[16] = 0x64000;    graph[17] = 0x10000;
        graph[18] = 0x290000;   graph[19] = 0x140800;
        graph[20] = 0x80000;    graph[21] = 0xc40000;
        graph[22] = 0x200000;   graph[23] = 0x41200000;
        graph[24] = 0x2800400;  graph[25] = 0x1000000;
        graph[26] = 0x18000400; graph[27] = 0x4000000;
        graph[28] = 0x64000000; graph[29] = 0x10000000;
        graph[30] = 0x90800000; graph[31] = 0x40000000;

    #else
        NODE_POINT = 0; CPU_DONE = 0; 
        START_POINT = 4; END_POINT = 18;

        uint32_t *graph     = (uint32_t *) 0x00001010;
        uint8_t  *dist      = (uint8_t *)  0x00001090;
        uint8_t  *parent    = (uint8_t *)  0x000010B0;
        uint32_t *sptSet    = (uint32_t *) 0x00001088;
        uint8_t  *min       = (uint8_t *)  0x0000108D;
        uint8_t  *min_index = (uint8_t *)  0x0000108C;

        *(graph + 0x00) = 0x442;      *(graph + 0x01) = 0x805;
        *(graph + 0x02) = 0x3a;       *(graph + 0x03) = 0x4;
        *(graph + 0x04) = 0x4;        *(graph + 0x05) = 0x4;
        *(graph + 0x06) = 0x381;      *(graph + 0x07) = 0x40;
        *(graph + 0x08) = 0x40;       *(graph + 0x09) = 0x40;
        *(graph + 0x0A) = 0x5000801;  *(graph + 0x0B) = 0x81402;
        *(graph + 0x0C) = 0x6800;     *(graph + 0x0D) = 0x1000;
        *(graph + 0x0E) = 0x19000;    *(graph + 0x0F) = 0x4000;
        *(graph + 0x10) = 0x64000;    *(graph + 0x11) = 0x10000;
        *(graph + 0x12) = 0x290000;   *(graph + 0x13) = 0x140800;
        *(graph + 0x14) = 0x80000;    *(graph + 0x15) = 0xc40000;
        *(graph + 0x16) = 0x200000;   *(graph + 0x17) = 0x41200000;
        *(graph + 0x18) = 0x2800400;  *(graph + 0x19) = 0x1000000;
        *(graph + 0x1A) = 0x18000400; *(graph + 0x1B) = 0x4000000;
        *(graph + 0x1C) = 0x64000000; *(graph + 0x1D) = 0x10000000;
        *(graph + 0x1E) = 0x90800000; *(graph + 0x1F) = 0x40000000;
    #endif

    // Dijkstra
    *sptSet = 0;

    for (int i = 0; i < V; i++) {
        *(dist + i)   = UCHAR_MAX;
        *(parent + i) = UCHAR_MAX;
    }

    //NODE_POINT = START_POINT;
    *(dist + START_POINT) = 0;


    for(int count = 0; count < V - 1; count++){
        *min = UCHAR_MAX;
        for (int v = 0; v < V; v++) {
            if (!get_bit(sptSet, v) && (*(dist + v) < *min)) {
                *min       = *(dist + v);
                *min_index = v;
            }
        }

        set(sptSet, *min_index);

        for (int v = 0; v < V; v++) {
            if (!get_bit(sptSet, v) && get_bit(graph + *min_index , v) && *(dist + *min_index) != UCHAR_MAX && (*(dist + *min_index) + get_bit(graph + *min_index , v) < *(dist + v))) {
                *(dist + v)   = *(dist + *min_index) + get_bit(graph + *min_index , v);	// Updating the distance of node v;
                *(parent + v) = *min_index;							// Setting the parent node of v as u;
            }
        }
    }

    idx = retracePath(parent, END_POINT, path_planned);
    *path_planned = START_POINT;
    reverse_path(path_planned, idx);

    // ##############################################

    // the node values are written into data memory sequentially.
    for (int i = 0; i < idx; ++i) {
        NODE_POINT = path_planned[i];
    }
    // Path Planning Computation Done Flag
    CPU_DONE = 1;

    #if defined(__linux__) || defined(__APPLE__) || defined(__unix__) // for host pc

        _put_str("######### Planned Path #########\n");
        for (int i = 0; i < idx; ++i) {
            _put_value(path_planned[i]);
        }
        _put_str("################################\n");

    #endif

    return 0;
}

