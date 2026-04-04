#!/bin/bash

set -e

# Input file
infile="$1"
[ -z "$infile" ] && { echo "Usage: $0 <file.c>"; exit 1; }

basename="${infile##*/}"
filename="${basename%.*}"

# Paths
CFG_DIR="./config"
LINKER="$CFG_DIR/linker.ld"
STARTUP="$CFG_DIR/start.s"
TRAP_HANDLER="./code/trap_handler.c"

# Architecture
ARCH=rv32im_zicsr

# Memory config
ROM=2048    # 2K
RAM=2048    # 2K
STACK=256   # 0.25K

# Toolchain
CC=riscv64-unknown-elf-gcc
OBJDUMP=riscv64-unknown-elf-objdump
OBJCOPY=riscv64-unknown-elf-objcopy
SIZE=riscv64-unknown-elf-size

# Compiler flags (freestanding, no libc)
CFLAGS="-march=$ARCH -mabi=ilp32 -Os -g3 -Wall -ffreestanding -nostdlib"
CFLAGS+=" -Wa,-march=$ARCH"

# Linker flags
LDFLAGS="-march=$ARCH -mabi=ilp32 -nostdlib -nostartfiles"
LDFLAGS+=" -Wl,--gc-sections"
LDFLAGS+=" -Wl,--defsym=__flash=0x00000000,--defsym=__flash_size=$ROM"
LDFLAGS+=" -Wl,--defsym=__ram=0x00002000,--defsym=__ram_size=$RAM"
LDFLAGS+=" -Wl,--defsym=__stack_size=$STACK"
LDFLAGS+=" -T $LINKER"

# Clean temp
rm -f .temp.*

# Build
if \
   $CC $CFLAGS -c "$STARTUP" -o .temp.start.o && \
   $CC $CFLAGS -c "$infile" -o .temp.file.o && \
   $CC $CFLAGS -c "$TRAP_HANDLER" -o .temp.trap.o && \
   $CC $LDFLAGS -o .temp.file.elf .temp.start.o .temp.file.o .temp.trap.o && \
   $OBJDUMP --visualize-jumps -t -S --source-comment='     ### ' \
       .temp.file.elf -M no-aliases,numeric > "$filename.lss" && \
   $OBJCOPY -O binary .temp.file.elf .temp.file.bin && \
   truncate -s $ROM .temp.file.bin && \
   $OBJCOPY --verilog-data-width=4 --reverse-bytes=4 \
       -I binary -O verilog .temp.file.bin "$filename.hex" && \
   $SIZE -B --common .temp.file.elf
then
    echo "✓ Successfully generated $filename.hex and $filename.lss from $infile"
    mkdir -p /runs/bin
    mv "$filename.hex" /runs/bin/
    mv "$filename.lss" /runs/bin/
    rm -f .temp.*
else
    echo "✗ Error: build failed from $infile"
    rm -f .temp.* "$filename.hex" "$filename.lss"
    exit 1
fi