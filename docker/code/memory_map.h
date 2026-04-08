
// Memory-mapped I/O addresses for peripherals
#define QSPI_BASE        0x00002000
#define QSPI_CSR_ADDR    (*(volatile uint32_t *)(QSPI_BASE + 0x00)) // ctsr: {23'd0, clk_div, auto_wren, cont_read, quad, enable}
#define QSPI_OPCODE_ADDR (*(volatile uint32_t *)(QSPI_BASE + 0x04)) // Opcode for current transfer (e.g., 0xEB for Quad I/O Read)
#define QSPI_ADDR_ADDR   (*(volatile uint32_t *)(QSPI_BASE + 0x08)) // Address for current transfer (e.g., 24-bit address for Quad I/O Read)
#define QSPI_DONE_ADDR   (*(volatile uint32_t *)(QSPI_BASE + 0x0C)) // Status bit: 0 = busy, 1 = done (auto-clears on new transfer)
#define QSPI_XLEN_ADDR   (*(volatile uint32_t *)(QSPI_BASE + 0x10)) // Transfer length in bytes for current transfer (e.g., 16 for Quad I/O Read of 16 bytes)
#define QSPI_CLKDIV_ADDR (*(volatile uint32_t *)(QSPI_BASE + 0x14)) // clock divisor
#define QSPI_TXBUF_STAT  (*(volatile uint32_t *)(QSPI_BASE + 0x18)) // status: {30'd0, tx_empty, tx_full}
#define QSPI_RXBUF_STAT  (*(volatile uint32_t *)(QSPI_BASE + 0x1C)) // status: {30'd0, rx_empty, rx_full}
#define QSPI_TXDATA_BUF  (*(volatile uint32_t *)(QSPI_BASE + 0x20)) // write-only buffer for TX data (e.g., data to be sent in Quad I/O Read command)
#define QSPI_RXDATA_BUF  (*(volatile uint32_t *)(QSPI_BASE + 0x24)) // read-only buffer for RX data (e.g., data received from Quad I/O Read command)

#define UART_BASE  0x00002040
#define UART_USR0  (*(volatile uint32_t *)(UART_BASE + 0x00))  // ctsr:  {ne,fe,pe,owe,idle,tc,rxne,txe}
#define UART_URDR  (*(volatile uint32_t *)(UART_BASE + 0x04))  // RX Data Register (read)
#define UART_UTDR  (*(volatile uint32_t *)(UART_BASE + 0x08))  // TX Data Register (write)
#define UART_UCR1  (*(volatile uint32_t *)(UART_BASE + 0x0C))  // Control: {IERXNE,IETXE,PS,PCE,M,RE,TE,UE}
#define UART_UBRR  (*(volatile uint32_t *)(UART_BASE + 0x10))  // Baud Rate Register

#define TIMER_BASE 0x00002080
#define TIMER_TCCR (*(volatile uint32_t *)(TIMER_BASE + 0x00))  // Status: {13'd0, T1_IRQ_EN, T1_PWM_EN, T1_EN, 13'd0, T0_IRQ_EN, T0_PWM_EN, T0_EN}
#define TIMER_TCNT (*(volatile uint32_t *)(TIMER_BASE + 0x04))  // Timer counter register
#define TIMER_OCMR (*(volatile uint32_t *)(TIMER_BASE + 0x08))  // Output compare match register (value to compare against TCNT for generating IRQ/PWM)

#define GPIO_BASE  0x000020C0
#define GPIO_GDIR  (*(volatile uint32_t *)(GPIO_BASE + 0x00))   // Data direction register: 0 = input, 1 = output
#define GPIO_GDAT  (*(volatile uint32_t *)(GPIO_BASE + 0x04))   // Data register: read to get input pin values, write to set output pin values

#define MM_BASE      0x00002100
#define MM_CTSR      (*(volatile uint32_t *)(MM_BASE + 0x00)) // ctsr: {30'b0, done, start}
#define MM_MATA_PTR  ((volatile uint32_t *)(MM_BASE + 0x04))  // pointer
#define MM_MATB_PTR  ((volatile uint32_t *)(MM_BASE + 0x44))
#define MM_MATC_PTR  ((volatile uint32_t *)(MM_BASE + 0x84))

// for testing
#define TEST_LOC (*(volatile uint32_t *)(0x00001000))
