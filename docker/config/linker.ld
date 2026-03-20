ENTRY(_start)

MEMORY
{
    flash (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    ram   (rwx) : ORIGIN = 0x00001000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.init)
        *(.text*)
        *(.rodata*)
    } > flash

    .data : {
        *(.data*)
    } > ram AT > flash

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > ram

    .stack (NOLOAD) : {
        . = ALIGN(16);
        _stack_top = ORIGIN(ram) + LENGTH(ram);
    } > ram
}