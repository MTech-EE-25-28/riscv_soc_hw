.section .trap_vector
.global __trap_vector_start
.align 6   # 64-byte alignment

__trap_vector_start:

    # 0: exceptions
    j exception_handler

    # Interrupts (mcause index)
    j isr_spi        # 1
    j isr_uart       # 2
    j isr_gpio       # 3
    j isr_timer      # 4
    j isr_mm         # 5

    # Fill rest (optional safety)
    .rept 26
        j exception_handler
    .endr
