#!/bin/bash

[ ! -z "${1}" ] && infile="${1}" # || infile="path_planner.c"
basename="${1##*/}" # remove folder path
filename="${basename%.*}"

ARCH=rv32i
ROM=2048     # Program segment: 2KB (0x000-0x7FF)
RAM=2048     # Data segment: 2KB (0x800-0xFFF)
STACK=256

CFLAGS="  -march=$ARCH -mabi=ilp32 --specs=picolibc.specs -Os -g3 -flto -DPICOLIBC_INTEGER_PRINTF_SCANF -Wall"
LDFLAGS=" -march=$ARCH -mabi=ilp32 --specs=picolibc.specs -Os -g3 -flto -DPICOLIBC_INTEGER_PRINTF_SCANF "
LDFLAGS+=" -Wl,--gc-sections,--defsym=__flash=0x00000000,--defsym=__flash_size=$ROM --crt0=minimal" #" -nostartfiles"
LDFLAGS+=" -Wl,--defsym=__ram=0x00000800,--defsym=__ram_size=$RAM,--defsym=__stack_size=$STACK -Tpicolibc.ld"

if riscv64-unknown-elf-gcc $CFLAGS -c $infile -o .temp.file.o && \
   riscv64-unknown-elf-gcc $LDFLAGS -o .temp.file.elf .temp.file.o && \
   riscv64-unknown-elf-objdump --visualize-jumps -t -S --source-comment='     ### ' .temp.file.elf -M no-aliases,numeric > $filename.lss && \
   riscv64-unknown-elf-objcopy -O binary .temp.file.elf .temp.file.bin && \
   truncate -s $ROM .temp.file.bin && \
   riscv64-unknown-elf-objcopy --verilog-data-width=4 --reverse-bytes=4 -I binary -O verilog .temp.file.bin $filename.hex && \
   riscv64-unknown-elf-size -B --common .temp.file.elf; then

    echo "✓ Successfully generated $filename.hex and $filename.lss from $infile"
    mkdir -p /runs/bin
    mv $filename.hex /runs/bin/$filename.hex
    mv $filename.lss /runs/bin/$filename.lss
    rm -f .temp.file.*
else
    echo "✗ Error: $infile could not be converted into binary format"
    rm -f .temp.file.* $filename.lss $filename.hex
    exit 1
fi
