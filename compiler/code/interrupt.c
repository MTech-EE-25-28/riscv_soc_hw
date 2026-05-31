
#include <stdint.h>

// Memory-mapped I/O addresses for peripherals
#define UART_BASE  0x00002000

#define UART_DATA  (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_STATUS (*(volatile uint32_t *)(UART_BASE + 0x08))

#define GPIO_BASE  0x00002010
#define GPIO_DIR   (*(volatile uint32_t *)(GPIO_BASE + 0x04))
#define GPIO_DATA  (*(volatile uint32_t *)(GPIO_BASE + 0x08))

#define TIMER_BASE 0x00002020
#define TIMER_DATA (*(volatile uint32_t *)(TIMER_BASE + 0x04))
#define TIMER_CTRL (*(volatile uint32_t *)(TIMER_BASE + 0x08))

#define SPI_BASE   0x00002030
#define SPI_DATA   (*(volatile uint32_t *)(SPI_BASE + 0x04))
#define SPI_STATUS (*(volatile uint32_t *)(SPI_BASE + 0x08))

#define MM_BASE    0x00002100
#define MM_A       (*(volatile uint32_t *)(MM_BASE + 0x00))
#define MM_B       (*(volatile uint32_t *)(MM_BASE + 0x80))
#define MM_C       (*(volatile uint32_t *)(MM_BASE + 0x100))
#define MM_CTRL    (*(volatile uint32_t *)(MM_BASE + 0x180))
#define MM_STATUS  (*(volatile uint32_t *)(MM_BASE + 0x184))

// for testing
#define TEST_LOC (*(volatile uint32_t *)(0x00001000))

// Trap handler prototype (defined in assembly)
extern void trap_handler();

void __attribute__((interrupt("machine"))) trap_handler (void) {
    uint32_t mepc, mcause;
    asm volatile ("csrr %0, mcause" : "=r"(mcause));

    if (mcause & 0x80000000) {
        // Interrupt
        // mepc already points to the interrupted instruction
        uint32_t id = mcause & 0x1F;
        // switch case needs jump table to be loaded into dmem
        if (id == 16) { // SPI — read received byte to clear RX interrupt flag
            (void) SPI_DATA;
            SPI_STATUS = 0;
            TEST_LOC = 1;
        } else if (id == 17) { // UART — read received byte to drain RX FIFO
            (void) UART_DATA;
            UART_STATUS = 0;
            TEST_LOC = 1;
        } else if (id == 18) { // GPIO — read pin state to clear edge-detect flag
            (void) GPIO_DATA;
            TEST_LOC = 1;
        } else if (id == 19) { // Timer — acknowledge by clearing the timer interrupt flag
            TIMER_CTRL = 0;
            TEST_LOC = 1;
        } else if (id == 20) { // Matrix Mul ignored
            TEST_LOC = 1;
        }

    } else {
        // Synchronous exception
        asm volatile ("csrr %0, mepc" : "=r"(mepc));
        mepc += 4; // put mepc on the next instruction
        asm volatile ("csrw mepc, %0" : : "r"(mepc));
        // Log cause to UART for debug visibility
        UART_DATA   = mcause;
        UART_STATUS = 1;
    }
}

int main() {

    // Set trap handler — direct mode (mtvec[1:0]=00): all traps go to trap_handler
    // For vectored mode set mtvec = (base | 1): interrupts go to base + mcause[4:0]*4
    asm("csrw mtvec, %0" :: "r"(trap_handler));
    // asm(".word 0xdeadcafe");
    asm volatile ("csrw mtvec, %0" :: "r"(trap_handler));
    // Enable machine-mode interrupts (mstatus.MIE = 1)
    asm volatile ("csrsi mstatus, 8"); // set bit 3 (MIE)

    // asm volatile ("ecall");
    // asm volatile ("ebreak");
    while (1);

    return 0;
}