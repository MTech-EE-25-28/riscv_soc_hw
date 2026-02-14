
## RISC-V Compiler

RISC-V Compiler is setup in Docker environment, why to tamper our system dependecies :\

Change the compile.sh to change the ISA extension, linker options, and memory addresses of the RISC-V compiler.

### References

Read about RISC-V Compiler over [here 🔗](https://riscv.org/blog/unveiling-the-tasking-risc-v-compiler-a-breakthrough-regarding-the-development-of-fusa-and-cybersecurity-compliant-software/) and compiler options are [here 🔗](https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html)

### Usage

Build the Docker

```
    docker build -t riscv_tools .
```

Run the Docker

```
    docker run riscv_tools <filename.c>
```
