
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
- Communication Protocol: UART, SPI
- GPIO Peripheral
- Memory Mapped Peripherals
- Matrix Multiplier

### Usage

- Use the [Docker 🔗](./docker/readme.md) to build the hex file.
- Move the hex file location to instruction memory directory and set the correct path.
- Run `simulate.sh` for local simulation, add wave flag to use gtkwave to see vcd.

    ```
        ./simulate.sh testbench [wave]
    ```

    **Example:** testbench name is `tb_pl`, the script will automatically add all the verilog files in the `../` directory. No need to include in the module definition.

    ```
        ./simulate.sh tb_pl wave
    ```

## TODOs

- [x] Update memory architecture and test it
    - [x] Change Data Mem to Xilinx BRAM Interface
    - [x] Change Instr Mem to be sequential
- [x] Implement Two-bit branch predictor and test it
- [x] RV32M Extension
    - [x] Implement 32-bit signed multiplier (maybe extend from 16-bit dadda)
    - [x] Implement Divider
    - [x] Implement Reminder
- [ ] CSR Extension
- [ ] AXI-Lite to AXI Full
- [ ] UART, SPI Integeration with AXI
- [ ] GPIO Peripheral
- [ ] Systolic Matrix Multiplier

### References

- Digital Design and Computer Architecture book
- Read about RISC-V Compiler over [here 🔗](https://riscv.org/blog/unveiling-the-tasking-risc-v-compiler-a-breakthrough-regarding-the-development-of-fusa-and-cybersecurity-compliant-software/) and compiler options are [here 🔗](https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html)

### Note to Developers

Do not add unnecssary files like project build files only add design files :/ . Make sure to give proper commit message.