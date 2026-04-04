
// Memory-mapped I/O addresses for peripherals
#define QSPI_BASE   0x00002000
#define QSPI_DATA   (*(volatile uint32_t *)(QSPI_BASE + 0x04))
#define QSPI_STATUS (*(volatile uint32_t *)(QSPI_BASE + 0x08))

#define UART_BASE  0x00002040
#define UART_DATA  (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_STATUS (*(volatile uint32_t *)(UART_BASE + 0x08))

#define TIMER_BASE 0x00002080
#define TIMER_TCCR (*(volatile uint32_t *)(TIMER_BASE + 0x00))
#define TIMER_TCNT (*(volatile uint32_t *)(TIMER_BASE + 0x04))
#define TIMER_OCMR (*(volatile uint32_t *)(TIMER_BASE + 0x08))

#define GPIO_BASE  0x000020C0
#define GPIO_DIR   (*(volatile uint32_t *)(GPIO_BASE + 0x04))
#define GPIO_DATA  (*(volatile uint32_t *)(GPIO_BASE + 0x08))

#define MM_BASE    0x00002100
#define MM_A       (*(volatile uint32_t *)(MM_BASE + 0x00))
#define MM_B       (*(volatile uint32_t *)(MM_BASE + 0x80))
#define MM_C       (*(volatile uint32_t *)(MM_BASE + 0x100))
#define MM_CTRL    (*(volatile uint32_t *)(MM_BASE + 0x180))
#define MM_STATUS  (*(volatile uint32_t *)(MM_BASE + 0x184))

// for testing
#define TEST_LOC (*(volatile uint32_t *)(0x00001000))
