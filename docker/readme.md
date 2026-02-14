
## RISC-V Compiler

RISC-V Compiler is setup in Docker environment, why to tamper our system dependecies :\

Change the compile.sh to change the ISA extension, linker options, and memory addresses of the RISC-V compiler.

### Usage

Assuming you already have docker image in your system, else install it from the docker official documentation.

Build the Docker

```
    docker build -t riscv_tools .
```

Run the Docker

```
    docker run riscv_tools <filename.c>
```
