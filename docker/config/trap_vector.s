.section .trap_vector, "ax", @progbits
.global __trap_vector_start
.align 2   # 4-byte alignment (required for RISC-V instructions)

__trap_vector_start:
    # Entry 0: Synchronous exceptions (direct jump to handler)
    j exception_handler
    .align 2

    # Entry 1-6: Reserved/unused (RISC-V standard interrupts)
    .rept 6
        j exception_handler  # Fallback to exception handler
        .align 2
    .endr

    # Entry 7: Machine Timer Interrupt (mcause=7, standard RISC-V MTIP)
    j isr_mtimer
    .align 2

    # Entry 8-15: Reserved/unused (RISC-V standard interrupts)
    .rept 8
        j exception_handler  # Fallback to exception handler
        .align 2
    .endr

    # Entry 16: Platform interrupt 0 - QSPI/SPI (mcause=16)
    j isr_spi
    .align 2

    # Entry 17: Platform interrupt 1 - UART (mcause=17)
    j isr_uart
    .align 2

    # Entry 18: Platform interrupt 2 - GPIO (mcause=18)
    j isr_gpio
    .align 2

    # Entry 19: Platform interrupt 3 - Timer (mcause=19)
    j isr_timer
    .align 2

    # Entry 20: Platform interrupt 4 - Matrix Multiplier (mcause=20)
    j isr_mm
    .align 2

    # Entries 21-31: Reserved for future platform interrupts
    .rept 11
        j exception_handler  # Fallback
        .align 2
    .endr
