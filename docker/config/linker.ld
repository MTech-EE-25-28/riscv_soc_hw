ENTRY(_start)

MEMORY {
    ROM       : ORIGIN = 0x00000000, LENGTH = 2K     /* Boot ROM */
    TRAP_VEC  : ORIGIN = 0x00000800, LENGTH = 512    /* Trap handler */
    TEXT      : ORIGIN = 0x00000A00, LENGTH = 1536   /* app space */
    DATA      : ORIGIN = 0x00001000, LENGTH = 2K     /* Data/stack */
}

SECTIONS {
    /* Trap vector section - at 0x800 */
    .trap_vector 0x00000800 : {
        KEEP(*(.trap_vector))
        *(.trap_handler)
    } > TRAP_VEC

    /* Application code section - starts at 0xA00 */
    .init 0x00000A00 : {
        *(.init)
    } > TEXT

    .text : {
        *(.text.init)
        *(.text)
        *(.text.*)
    } > TEXT

    /* Data section */
    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > DATA

    /* BSS section */
    .bss : {
        PROVIDE(__bss_start = .);
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        PROVIDE(__bss_end = .);
    } > DATA

    /* Stack (grows down from top of DATA, 256 bytes = 0.25K) */
    .stack (ORIGIN(DATA) + LENGTH(DATA) - 256) : {
        PROVIDE(_stack_top = .);
    } > DATA
}