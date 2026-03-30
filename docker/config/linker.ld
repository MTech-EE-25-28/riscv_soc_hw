ENTRY(_start)

MEMORY {
    ROM   : ORIGIN = 0x00000000, LENGTH = 4K      /* Boot ROM (trap vectors + code) */
    DATA  : ORIGIN = 0x00001000, LENGTH = 2K      /* Data + stack */
}

SECTIONS {

    /*  Trap Vector Table (in ROM) */
    .trap_vector : ALIGN(4) {
        __trap_vector_start = .;
        KEEP(*(.trap_vector))
        *(.trap_handler)
        __trap_vector_end = .;
    } > ROM

    /*  Startup Code */
    .init : ALIGN(4) {
        __init_start = .;
        *(.init)
        __init_end = .;
    } > ROM

    /*  Text Section */
    .text : ALIGN(4) {
        __text_start = .;
        *(.text.init)
        *(.text)
        *(.text.*)
        __text_end = .;
    } > ROM

    /*  Read-only Data */
    .rodata : ALIGN(4) {
        __rodata_start = .;
        *(.rodata)
        *(.rodata.*)
        __rodata_end = .;
    } > ROM

    /*  Initialized Data */
    .data : ALIGN(4) {
        __data_start = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        __data_end = .;
    } > DATA

    /*  BSS (Zero-initialized) */
    .bss : ALIGN(4) {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        __bss_end = .;
    } > DATA

    /*  Heap */
    .heap : ALIGN(4) {
        __heap_start = .;
        . = ORIGIN(DATA) + LENGTH(DATA) - 256;
        __heap_end = .;
    } > DATA

    /*  Stack (top of DATA) */
    .stack (ORIGIN(DATA) + LENGTH(DATA)) : {
        PROVIDE(_stack_top = .);
    } > DATA
}