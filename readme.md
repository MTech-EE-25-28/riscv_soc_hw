
## Course Project

To Design and Implement pipelined RISC-V (rv32im) CPU. Additionally, the CPU must interface a hardware accelerator in our case 8x8 systolic array matrix multiplier

### Quick Links

- Drive Folder [🔗](https://drive.google.com/drive/folders/1hxN554t5wVxOj4kZc2496kIRQUIQfFwi?usp=drive_link)
- Proposal Doc [🔗](https://docs.google.com/document/d/1fRPK1PpdDccjNj-pN-l28b1CndTj1wCNxMwHX3wDBww/edit?usp=sharing)
- Task Planning [🔗](https://docs.google.com/spreadsheets/d/1yrGrQKRs-R2LSBKFLWaHegrmFKYdW5KiHeWRzrjUArc/edit?usp=drive_link)

### Requirements

- Vivado
- iverilog
- GTKWave
- Docker

### CPU Specifications

- Clock Frequency: > 100 MHz (embedded profile)
- Extensions: IM, F if possible
- CSR Support: (zicsr)
- Memory Mapped Peripherals
    - Communication Protocol: UART, SPI
    - GPIO Peripheral
    - Matrix Multiplier

### Usage

- Use the [Docker 🔗](./docker/readme.md) to build the hex file.
- The simulation script automatically picks the hex file based on the testbench name. So make sure to follow the naming convention for testbenches as mentioned in the script. If required modify the script to add more testbenches and corresponding hex files.
- Run `simulate.sh` for local simulation, add wave flag to use gtkwave to see vcd.

    ```
        ./simulate.sh testbench [wave]
    ```

    **Example:** testbench name is `tb_pl`, the script will automatically add all the verilog files in the `../` directory. No need to include in the module definition.

    ```
        ./simulate.sh tb_pl wave
    ```

- Run `tests.sh` to run all the testbenches sequentially. This will run the testbenches without waveforms.

    ```
        ./tests.sh
    ```

## TODOs

- [x] Update memory architecture and test it
    - [x] Change Data Mem to Xilinx BRAM Interface
    - [x] Change Instr Mem to be sequential (switched back to combinational)
- [x] Implement Two-bit branch predictor and test it
- [x] RV32M Extension
    - [x] Implement 32-bit signed multiplier (maybe extend from 16-bit dadda)
    - [x] Implement Divider
    - [x] Implement Reminder
- [x] zicsr Extension
    - [x] Implement CSR registers (cssrw, csrrs, csrrc with immediate variants)
    - [x] Implement mtvec, mepc, mstatus, mcause, mtval at minimum
    - [x] Implement MRET instruction
    - [x] Implement trap handler to handle exceptions and interrupts
- [x] AXI-Lite to AXI Full
- [x] UART, SPI Integeration with APB
- [x] GPIO Peripheral
- [x] Matrix Multiplier
    - [x] Design and implement systolic array matrix multiplier
    - [x] Integrate with CPU using APB
- [x] Test Matrix Multiplier with UART transfer in FPGA
- [x] Bootloader Interface to load program from flash to imem, dmem
- [ ] Synthesize and implement on ASIC

## Future Work

- [x] Bootloader code to load program from flash to imem, dmem
- [x] Update Linker to support vectored interrupts
- [ ] Implement Clint for timer interrupts
- Sky130 ASIC Flow with compiled memory for ROM and RAM
- Use AXI-APB bridge instead of direct APB interface
- Implement PLIC for external interrupts
- Implement F extension (floating point unit)
- Implement A extension (atomic instructions)
- Implement OS support (S-mode, U-mode, cache, clint, plic)

### References

- Digital Design and Computer Architecture book
- Read about RISC-V Compiler over [here 🔗](https://riscv.org/blog/unveiling-the-tasking-risc-v-compiler-a-breakthrough-regarding-the-development-of-fusa-and-cybersecurity-compliant-software/) and compiler options are [here 🔗](https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html)

### Note to Developers

Do not add unnecssary files like project build files only add design files :/ . Make sure to give proper commit message.