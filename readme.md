
## Course Project

To Design and Implement pipelined RISC-V (rv32im) CPU. Additionally, the CPU must interface a hardware accelerator in our case 4x4 systolic array matrix multiplier



### Note to Developers

Hey Devs, if you want to contribute to the project, please follow the below guidelines:

- To report bugs or issues, please create an issue in the GitHub repository with a clear description of the problem and steps to reproduce it.
- To contribute code, please fork the repository and create a pull request with your changes. Make sure to follow the coding style and conventions used in the project. Also, please include tests for your changes if applicable. Review the code and test it locally before creating a pull request.
- Do not add unnecssary files like project build files only add design files :/ . Make sure to give proper commit message.

### Requirements

- Vivado
- iverilog
- GTKWave
- Docker

### CPU Specifications

- Pipeline Design
- Clock Frequency: > 100 MHz (embedded profile)
- Extensions: IM, F if possible
- CSR Support: (zicsr)
- Memory Mapped Peripherals
    - Communication Protocol: UART, SPI
    - GPIO Peripheral
    - Matrix Multiplier

## Repository Structure

- `docker` - Contains Dockerfile and scripts to build the hex files for the testbenches.
- `docs` - contains ISA, report, and other project documents.
- `Verilog` - Contains all the verilog files for the CPU design, testbenches codes.

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

### Important

If you want to run the CPU on FPGA through bootloader, then change the state machine in `boot_loader.v` to `IDLE` instead of `FINISHED`. For adding new features and testing it in local simulation, you can set the state machine to `FINISHED` so that it directly jumps to executing the program in imem without waiting for the bootloader to load the program. Instead directly load the program into imem hex file and run the simulation.

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
- [x] Synthesize and implement on ASIC

## Future Work

- [x] Bootloader code to load program from flash to imem, dmem
- [x] Update Linker to support vectored interrupts
- [x] Implement Clint for timer interrupts
- Sky130 ASIC Flow with compiled memory for ROM and RAM
- Use AXI-APB bridge instead of direct APB interface
- Implement PLIC for external interrupts
- Implement F extension (floating point unit)
- Implement A extension (atomic instructions)
- Implement OS support (S-mode, U-mode, cache)

### References

- Digital Design and Computer Architecture book
- Read about RISC-V Compiler over [here 🔗](https://riscv.org/blog/unveiling-the-tasking-risc-v-compiler-a-breakthrough-regarding-the-development-of-fusa-and-cybersecurity-compliant-software/) and compiler options are [here 🔗](https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html)
