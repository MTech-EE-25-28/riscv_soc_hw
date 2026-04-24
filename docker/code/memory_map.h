
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

#define TIMER_BASE  0x00002080
#define TIMER_TCCR  (*(volatile uint32_t *)(TIMER_BASE + 0x00))  // Control: [8]=T2_IRQ_EN,[7]=T2_PWM_EN,[6]=T2_EN,[5]=T1_IRQ_EN,[4]=T1_PWM_EN,[3]=T1_EN,[2]=T0_IRQ_EN,[1]=T0_PWM_EN,[0]=T0_EN
#define TIMER_TCNT  (*(volatile uint32_t *)(TIMER_BASE + 0x04))  // Timer 0+1 counter (read-only): [31:16]=TCNT1, [15:0]=TCNT0
#define TIMER_TCNTF (*(volatile uint32_t *)(TIMER_BASE + 0x08))  // Timer 2 counter (read-only): 32-bit counter value
#define TIMER_OCMR  (*(volatile uint32_t *)(TIMER_BASE + 0x0C))  // Output compare 0+1: [31:16]=OCMR1, [15:0]=OCMR0 (compare match value for PWM/IRQ)
#define TIMER_OCMRF (*(volatile uint32_t *)(TIMER_BASE + 0x10))  // Output compare 2: 32-bit compare match value for PWM/IRQ
#define TIMER_TIRQ  (*(volatile uint32_t *)(TIMER_BASE + 0x14))  // Interrupt flags (read-only): [5]=T2_OVF,[4]=T2_CMP,[3]=T1_OVF,[2]=T1_CMP,[1]=T0_OVF,[0]=T0_CMP

#define GPIO_BASE  0x000020C0
#define GPIO_GDIR  (*(volatile uint32_t *)(GPIO_BASE + 0x00))   // Data direction register: 0 = input, 1 = output
#define GPIO_GDAT  (*(volatile uint32_t *)(GPIO_BASE + 0x04))   // Data register: read to get input pin values, write to set output pin values
#define GPIO_GIEN  (*(volatile uint32_t *)(GPIO_BASE + 0x08))   // Interrupt enable: 1 = interrupt enabled for pin (input pins only)
#define GPIO_GIRQ  (*(volatile uint32_t *)(GPIO_BASE + 0x0C))   // Interrupt flags (read-to-clear): 1 = edge detected on pin

#define MM_BASE      0x00002100
#define MM_CTSR      (*(volatile uint32_t *)(MM_BASE + 0x00)) // ctsr: {30'b0, done, start}
#define MM_MATA_PTR  ((volatile uint32_t *)(MM_BASE + 0x04))  // pointer
#define MM_MATB_PTR  ((volatile uint32_t *)(MM_BASE + 0x44))
#define MM_MATC_PTR  ((volatile uint32_t *)(MM_BASE + 0x84))

// CSR addresses for machine timer (custom CLINT-style implementation)
#define CSR_TIMECMPL  0x7C0  // Machine timer compare low (write to set timer deadline)
#define CSR_TIMECMPH  0x7C1  // Machine timer compare high
#define CSR_MCYCLEL   0xB00  // Machine cycle counter low (read-only)
#define CSR_MCYCLEH   0xB80  // Machine cycle counter high (read-only)
#define CSR_MIE       0x304  // Machine interrupt enable (bit 7 = MTIE)
#define CSR_MIP       0x344  // Machine interrupt pending (bit 7 = MTIP, read-only)

// for testing
#define TEST_LOC (*(volatile uint32_t *)(0x00001000))
