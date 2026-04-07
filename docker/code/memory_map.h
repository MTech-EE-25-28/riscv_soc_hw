
// Memory-mapped I/O addresses for peripherals
#define QSPI_BASE   0x00002000
#define QSPI_DATA   (*(volatile uint32_t *)(QSPI_BASE + 0x04))
#define QSPI_STATUS (*(volatile uint32_t *)(QSPI_BASE + 0x08))

#define UART_BASE  0x00002040
#define UART_USR0  (*(volatile uint32_t *)(UART_BASE + 0x00))  // Status:  {ne,fe,pe,owe,idle,tc,rxne,txe}
#define UART_URDR  (*(volatile uint32_t *)(UART_BASE + 0x04))  // RX Data Register (read)
#define UART_UTDR  (*(volatile uint32_t *)(UART_BASE + 0x08))  // TX Data Register (write)
#define UART_UCR1  (*(volatile uint32_t *)(UART_BASE + 0x0C))  // Control: {IERXNE,IETXE,PS,PCE,M,RE,TE,UE}
#define UART_UBRR  (*(volatile uint32_t *)(UART_BASE + 0x10))  // Baud Rate Register

#define TIMER_BASE 0x00002080
#define TIMER_TCCR (*(volatile uint32_t *)(TIMER_BASE + 0x00))
#define TIMER_TCNT (*(volatile uint32_t *)(TIMER_BASE + 0x04))
#define TIMER_OCMR (*(volatile uint32_t *)(TIMER_BASE + 0x08))

#define GPIO_BASE  0x000020C0
#define GPIO_GDIR  (*(volatile uint32_t *)(GPIO_BASE + 0x00))
#define GPIO_GDAT  (*(volatile uint32_t *)(GPIO_BASE + 0x04))

#define MM_BASE    0x00002100
#define MM_CTSR    (*(volatile uint32_t *)(MM_BASE + 0x0))
#define MM_MATA    (*(volatile uint32_t *)(MM_BASE + 0x04))
#define MM_MATB    (*(volatile uint32_t *)(MM_BASE + 0x44))
#define MM_MATC    (*(volatile uint32_t *)(MM_BASE + 0x84))

// for testing
#define TEST_LOC (*(volatile uint32_t *)(0x00001000))
