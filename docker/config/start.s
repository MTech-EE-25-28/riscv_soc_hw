.section .init
.globl _start

_start:
    la sp, _stack_top

    # install trap handler into mtvec (direct mode, bit[1:0]=0)
    la t0, trap_handler
    csrw mtvec, t0

    # enable machine-mode interrupts (MIE bit in mstatus)
    li t0, 0x8
    csrs mstatus, t0

    # zero .bss
    la t0, __bss_start
    la t1, __bss_end

1:
    bge t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b

2:
    call main

3:  j 3b
