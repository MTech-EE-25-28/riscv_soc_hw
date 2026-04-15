# RISC-V SoC — Software Flow

---

## 1. Overview

### 1.1 System Architecture

The RISC-V SoC implements a soft-core RV32IM processor on an FPGA, surrounded
by a set of memory-mapped peripherals connected through an AXI-lite bus fabric.
Rather than storing a fixed program in on-chip ROM at synthesis time, the SoC
incorporates a UART bootloader that receives the program image at run-time and
writes it directly into the CPU's instruction memory.  This design choice
allows new programs to be deployed to the running FPGA without re-synthesising
or re-programming the bitstream.

### 1.2 End-to-End Software Flow

Writing and running a program on the SoC involves four distinct phases:

```
  ┌─────────────────────────────────────────────────────────────────┐
  │  DEVELOPMENT (host PC)                                          │
  │                                                                 │
  │   C source file  ──►  cross-compiler (RV32IM, inside Docker)    │
  │                             │                                   │
  │                             ▼                                   │
  │                        ELF binary                               │
  │                             │                                   │
  │                    objcopy (flat binary)                        │
  │                             │                                   │
  │                    objcopy (Verilog hex)                        │
  │                             │                                   │
  │                         .hex file  ◄── used by simulation too   │
  └─────────────────────────────┬───────────────────────────────────┘
                                │  UART (boot_host.py / tb_boot.v)
  ┌─────────────────────────────▼───────────────────────────────────┐
  │  SoC (FPGA)                                                     │
  │                                                                 │
  │   Bootloader FSM ──► instruction memory (2 KB)                  │
  │        │                                                        │
  │        └── releases CPU reset after upload completes            │
  │                                                                 │
  │   CPU executes program; output via UART / memory-mapped regs    │
  └─────────────────────────────────────────────────────────────────┘
```

### 1.3 Memory Map

The CPU uses a flat 32-bit address space.  The address map is divided into
three functional zones: instruction memory, data memory, and memory-mapped
I/O (MMIO).

| Region | Base Address | Size | Description |
|---|---|---|---|
| Instruction ROM | `0x0000_0000` | 4 KB | Holds trap vector table, startup code, and compiled `.text` / `.rodata` |
| Data RAM | `0x0000_1000` | 2 KB | Runtime data: `.data`, `.bss`, heap, stack |
| MMIO — test | `0x0000_1000`–`0x0000_100F` | 16 B | Reserved: `TEST_LOC`, result output, halt flag |
| MMIO — QSPI | `0x0000_2000` | 64 B | SPI flash controller |
| MMIO — UART | `0x0000_2040` | 20 B | UART transmit / receive registers |
| MMIO — Timer | `0x0000_2080` | 12 B | Timer counter and PWM output |
| MMIO — GPIO | `0x0000_20C0` | 8 B | General-purpose digital I/O |
| MMIO — Matrix Mul | `0x0000_2100` | 140 B | Hardware matrix-multiply accelerator |

The instruction ROM and data RAM are separate physical memories.  The CPU
issues load/store instructions using byte addresses; the bus fabric routes
accesses to the correct peripheral based on the address range.

#### MMIO Test Region

The lowest 16 bytes of data RAM are reserved for test-bench and debug
communication.  Software should never allocate variables in this range.

| Address | Purpose |
|---|---|
| `0x0000_1000` | `TEST_LOC` — general-purpose scratch register, visible in simulation |
| `0x0000_1004` | Result output — write the numeric result here for the testbench to capture |
| `0x0000_1008` | Halt flag — writing `1` signals that the program has completed |

A program signals completion as:

```c
*(volatile uint32_t *)0x00001004 = result_value;
*(volatile uint32_t *)0x00001008 = 1;   // triggers $finish in tb_boot.v
```

#### Peripheral Register Summary

All peripherals are accessed via `volatile` pointer macros defined in
`docker/code/memory_map.h`.  The table below lists each peripheral's base
address and key registers.

**UART** (`0x0000_2040`):

| Offset | Name | Access | Description |
|---|---|---|---|
| `+0x00` | `UART_USR0` | R | Status: `{NE,FE,PE,OWE,IDLE,TC,RXNE,TXE}` |
| `+0x04` | `UART_URDR` | R | Received byte |
| `+0x08` | `UART_UTDR` | W | Byte to transmit |
| `+0x0C` | `UART_UCR1` | W | Control: `{IERXNE,IETXE,PS,PCE,M,RE,TE,UE}` |
| `+0x10` | `UART_UBRR` | W | Baud-rate divisor BRR |

Baud rate formula: `f_clk / (BRR × 16)`.  At 50 MHz with BRR = 27:
`50 000 000 / (27 × 16) = 115 740 baud ≈ 115 200 baud`.

**Timer** (`0x0000_2080`):

| Offset | Name | Description |
|---|---|---|
| `+0x00` | `TIMER_TCCR` | Control: `{T1_IRQ_EN, T1_PWM_EN, T1_EN, …, T0_IRQ_EN, T0_PWM_EN, T0_EN}` |
| `+0x04` | `TIMER_TCNT` | Current counter value |
| `+0x08` | `TIMER_OCMR` | Compare-match register (triggers interrupt / PWM toggle) |

**GPIO** (`0x0000_20C0`):

| Offset | Name | Description |
|---|---|---|
| `+0x00` | `GPIO_GDIR` | Direction: `1` = output, `0` = input (per bit) |
| `+0x04` | `GPIO_GDAT` | Data: read input levels / write output levels |

---

## 2. Compiler Setup

### 2.1 Cross-Compilation Rationale

Because the SoC implements a RISC-V (RV32IM) ISA and the development machine
runs an x86-64 or ARM host, a cross-compiler is required.  The chosen target
triple is `riscv64-unknown-elf`, which despite the `64` in the name can target
32-bit ABIs by specifying the `-march=rv32im -mabi=ilp32` flags.  The toolchain
is packaged inside a Docker container so that no permanent changes are made to
the host system and the compilation environment is fully reproducible.

### 2.2 Docker Container

The container is based on `debian:bookworm-slim` and installs only two
packages:

- `gcc-riscv64-unknown-elf` — the full GNU toolchain (compiler, assembler,
  linker, objcopy, objdump, size utility).
- `picolibc-riscv64-unknown-elf` — a lightweight C library providing headers
  such as `stdint.h` (no standard I/O functions are linked in).

The `compile.sh` script is installed as the container's `ENTRYPOINT`, so
invoking the container with a `.c` filename immediately compiles and produces
the `.hex` output with no additional shell interaction required.

Build the image once:

```bash
cd docker/
docker build -t riscv_tools .
```

### 2.3 Compiler Flags

The following flags are passed to `riscv64-unknown-elf-gcc`:

| Flag | Purpose |
|---|---|
| `-march=rv32im_zicsr` | Target the RV32IM ISA with the Zicsr extension (CSR instructions needed for interrupt handling) |
| `-mabi=ilp32` | 32-bit integer / pointer ABI |
| `-Os` | Optimise for code size (important given the 4 KB instruction memory limit) |
| `-ffreestanding` | Do not assume a hosted environment; do not link the standard C startup or library |
| `-nostdlib` | Do not link any default libraries |
| `-g3` | Generate full debug information (used by the disassembly listing) |
| `-Wall` | Enable all warnings |

### 2.4 Linker Script

The GNU linker is directed by `config/linker.ld`, which is central to
producing a binary that is correctly laid out for the SoC's memory map.

#### Memory Regions

```
MEMORY {
    ROM  : ORIGIN = 0x00000000, LENGTH = 4K
    DATA : ORIGIN = 0x00001000, LENGTH = 2K
}
```

The `ROM` region maps to the instruction memory.  The `DATA` region maps to
the data RAM.  The linker uses these definitions to assign a *load memory
address* (LMA) and a *virtual memory address* (VMA) to each output section.

#### Output Sections

Sections are placed in the output binary in the following order:

| Section | Region | VMA | Contents |
|---|---|---|---|
| `.trap_vector` | ROM | `0x0000_0000` | Exception and interrupt handler jump table |
| `.init` | ROM | after `.trap_vector` | `_start` (entry point) |
| `.text` | ROM | after `.init` | All compiled function bodies |
| `.rodata` | ROM | after `.text` | Compile-time constants, string literals |
| `.data` | DATA | `0x0000_1010` | Initialised global and static variables |
| `.bss` | DATA | after `.data` | Zero-initialised globals and statics |
| `.heap` | DATA | after `.bss` | Heap (grows upward toward stack) |
| `.stack` | DATA | `0x0000_1800` | Stack top (grows downward) |

The `.data` section starts at `0x0000_1010` (not `0x0000_1000`) because the
first 16 bytes of the DATA region are reserved for the MMIO test registers
described in Section 1.3.  The linker script enforces this with an explicit
`. += 0x10;` directive inside the `.data` section definition.

#### Interrupt / Exception Vectors

The `.trap_vector` section, placed at the very start of ROM (`0x0000_0000`),
contains a table of `j` (unconditional jump) instructions.  When an exception
or interrupt occurs the hardware jumps to `mtvec` (set to `0x0000_0000` in
direct mode).  The first entry handles all synchronous exceptions; subsequent
entries correspond to peripheral interrupt sources in order of their interrupt
ID:

| Entry offset | Handler | Source |
|---|---|---|
| `+0x00` | `exception_handler` | All synchronous exceptions |
| `+0x04` | `isr_spi` | QSPI controller |
| `+0x08` | `isr_uart` | UART RX |
| `+0x0C` | `isr_gpio` | GPIO edge detect |
| `+0x10` | `isr_timer` | Timer compare-match |
| `+0x14` | `isr_mm` | Matrix-multiply done |

The section is 64-byte aligned (`.align 6`) so that the fixed-offset indexing
by the hardware is always correct.

### 2.5 Startup Code (`config/start.s`)

The startup assembly file provides the `_start` symbol, which is the ELF
entry point.  Its responsibilities are:

1. **Stack pointer initialisation** — loads the symbol `_stack_top` (the top
   of the DATA region, `0x0000_1800`) into register `sp`.
2. **Trap vector registration** — writes the address of `trap_handler` into
   `mtvec` using a `csrw` instruction.  The vector is installed in *direct
   mode* (bits `[1:0]` = `0`), which means all traps jump to the same address
   and the handler dispatches on `mcause`.
3. **Interrupt enable** — sets the `MIE` bit (`bit 3`) in `mstatus` to
   globally enable machine-mode interrupts.
4. **BSS zeroing** — iterates from `__bss_start` to `__bss_end` (symbols
   provided by the linker script) and writes zero to each word.  This
   satisfies the C standard guarantee that zero-initialised globals are zero
   at program entry.
5. **`main` call** — calls `main`.  On return, an infinite loop prevents the
   CPU from executing undefined memory.

### 2.6 Trap Handler (`code/trap_handler.c`)

The default trap handler is compiled as a separate translation unit and linked
into every program.  It uses the GCC attribute `__attribute__((interrupt("machine")))`,
which causes the compiler to save and restore all caller-saved registers and
use `mret` (rather than `ret`) to return.

The handler reads `mcause` to distinguish between:

- **Synchronous exceptions** (`mcause[31] = 0`) — advances `mepc` by 4 (to
  skip the faulting instruction) and sends the `mcause` value over UART for
  debug visibility.
- **Machine-mode interrupts** (`mcause[31] = 1`) — dispatches on the interrupt
  ID field `mcause[4:0]` to service the appropriate peripheral (UART, Timer,
  GPIO, QSPI, or Matrix-Mul).

### 2.7 Hex File Generation

The toolchain produces the `.hex` file through the following pipeline:

1. **ELF → flat binary** (`objcopy -O binary`): strips all ELF metadata and
   produces a raw byte image laid out exactly as the linker script specifies.
2. **Padding** (`truncate`): the binary is padded to exactly
   `ROM_SIZE + DATA_SIZE = 4096 + 2048 = 6144 bytes` so that the Verilog
   `$readmemh` task fills both memories completely.
3. **Binary → Verilog hex** (`objcopy --verilog-data-width=4 --reverse-bytes=4 -I binary -O verilog`):
   groups bytes into 32-bit little-endian words and writes one word per line
   in ASCII hexadecimal.  The `--reverse-bytes=4` corrects for the fact that
   `objcopy` writes in big-endian order by default, restoring the native
   little-endian word layout expected by the Verilog `$readmemh` loader.

---

## 3. Usage

### 3.1 Writing a C Program

Source files live in `docker/code/`.  Because the build is freestanding
(no standard library), standard I/O functions such as `printf` are not
available.  Programs must use `stdint.h` fixed-width types and access
peripherals exclusively through the `volatile` macros in `memory_map.h`.

A minimal skeleton that computes a result and signals completion:

```c
#include <stdint.h>
#include "memory_map.h"

int main(void) {
    uint32_t result = 0;

    /* --- computation --- */
    for (uint32_t i = 1; i <= 10; i++)
        result += i;   // sum 1..10 = 55

    /* --- report result and halt --- */
    *(volatile uint32_t *)0x00001004 = result;
    *(volatile uint32_t *)0x00001008 = 1;      // halt flag
    return 0;
}
```

Key constraints:
- `.text` + `.rodata` must fit within 4 KB (instruction ROM).
- `.data` + `.bss` + heap must fit within approximately 1 792 bytes
  (2 KB DATA minus 16 B MMIO reservation minus 256 B stack).
- Do **not** access addresses `0x0000_1000`–`0x0000_100F` through normal
  variables; use the `volatile` pointer convention shown above.
- To use UART output, initialise the peripheral before transmitting
  (`UART_UBRR = 0x1B; UART_UCR1 = 0x07;`).

### 3.2 Compiling with Docker

From the `docker/` directory, mount the `code/` and `bin/` directories into
the container and pass the relative path to the source file:

```bash
docker run --rm \
    -v "$PWD/code:/runs/code" \
    -v "$PWD/bin:/runs/bin"  \
    riscv_tools code/<your_file>.c
```

On success the container prints a confirmation line and exits with code `0`:

```
✓ Successfully generated <your_file>.hex and <your_file>.lss from code/<your_file>.c
```

Both output files are written to `docker/bin/`:

| File | Description |
|---|---|
| `<your_file>.hex` | Verilog `$readmemh` image — input to simulation and bootloader upload |
| `<your_file>.lss` | Annotated disassembly with source interleaving — useful for debugging |

To inspect the disassembly and verify section placement:

```bash
less docker/bin/<your_file>.lss
```

### 3.3 Uploading to the Board

`boot_host.py` implements the host side of the UART boot protocol and
replaces the Verilog testbench (`tb_boot.v`) when running on real hardware.

#### Finding the Serial Port

On **macOS**:
```bash
ls /dev/tty.*          # lists all serial devices
# look for: /dev/tty.usbserial-XXXX  or  /dev/tty.usbmodem-XXXX
```

On **Linux**:
```bash
ls /dev/ttyUSB*        # FTDI / CH340 adapters
ls /dev/ttyACM*        # CDC-ACM (Arduino-style)
```

Plug the board in, run the command before and after — the new entry is your
port.

#### Running the Upload Script

```bash
python docker/boot_host.py \
    -p /dev/tty.usbserial-0001 \
    -b 115200 \
    -n <word_count> \
    docker/bin/<your_file>.hex
```

| Option | Default | Description |
|---|---|---|
| `-p / --port` | `/dev/ttyUSB0` | Serial device path |
| `-b / --baud` | `115200` | Baud rate (SoC runs at ≈ 115 740; 115 200 is accepted) |
| `-n / --words` | (all words in file) | Limit upload to the first N 32-bit words |
| `-t / --timeout` | `5.0` | Per-byte receive timeout in seconds |
| `-v / --verbose` | off | Print each word address and `X` acknowledgement |

#### Boot Protocol

The script follows a four-step handshake protocol defined by `boot_loader.v`:

1. **Handshake** — the bootloader sends `0xAA`; the host waits and checks it.
2. **Acknowledgement** — the host sends `0x55` to confirm it is ready.
3. **Image transfer** — for each 32-bit word in the hex file the host sends
   four bytes MSB-first, then waits for the bootloader to reply with `'X'`
   (`0x58`) confirming the word was written to instruction memory.
4. **CPU release** — after the host stops sending bytes, the bootloader's
   internal idle counter expires (after approximately 300 polling cycles with
   no new data on the RX line) and it de-asserts the CPU reset signal.  The
   CPU begins executing from address `0x0000_0000`.

Expected terminal output:

```
[BOOT] Loaded 120 words from docker/bin/sum.hex
[BOOT] Opened /dev/tty.usbserial-0001 @ 115200 baud
[BOOT] Waiting for handshake byte 0xAA from SoC …
[BOOT] Received handshake 0xAA  OK
[BOOT] Sending acknowledgement 0x55 to SoC …
[BOOT] Ack sent.
[BOOT] Streaming 120 words …
[BOOT] Progress: 120/120  (100%)
[BOOT] All 120 words sent and acknowledged  (0.55 s)
[BOOT] Waiting for CPU output (Ctrl-C to quit) …
55
[BOOT] No more data.  Done.
```

After the upload the script enters a receive loop and prints any bytes the
CPU sends over UART.  Printable ASCII characters are displayed as-is;
non-printable bytes are shown as `<0xNN>`.

### 3.4 Simulating Instead of Uploading

The Verilog testbench `Verilog/test/tb_boot.v` performs the same boot
protocol as `boot_host.py` and connects directly to the SoC DUT.  It reads
the same `.hex` file and drives the UART `rx` line at the bit level
(432 clock cycles per bit at 50 MHz / BRR 27).  Run the simulation from the
repository root:

```bash
./simulate.sh
```

The testbench monitors writes to `0x0000_1004` (result) and `0x0000_1008`
(halt flag).  When the halt flag is written, it prints `PASS` or `FAIL` and
calls `$finish`.
