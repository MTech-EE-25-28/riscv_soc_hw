
// riscv_pl.v - Pipelined RISC-V CPU Processor
module riscv_pl (
    input         clk, reset,
    input   [4:0] interruptA,
    input         apb_done,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWriteM,
    output        is_mem_accessM,
    output [31:0] Mem_WrAddr, Mem_WrData,
    output  [3:0] wea,
    input  [31:0] ReadData,
    output  [2:0] funct3,
    output [31:0] PCW, Result, ALUResultW, WriteDataW, ReadDataW
);

wire         ALUSrc, RegWrite, Jump, Jalr, csrSel, Branch;
wire         MemWrite, ierr, ecall, ebreak, ret, wfi;
wire  [1:0]  ResultSrc, ImmSrc;
wire  [4:0]  ALUControl;
wire [31:0]  InstrD;

controller  c   (InstrD[31:20], InstrD[6:0], InstrD[14:12], InstrD[30], InstrD[25],
                 ALUControl, ResultSrc, ImmSrc, MemWrite, ALUSrc, Branch,
                 RegWrite, Jump, Jalr, csrSel, ierr, ecall, ebreak, wfi, ret);

datapath    dp  (clk, reset, interruptA, ResultSrc,
                ALUSrc, RegWrite, ImmSrc, ALUControl, Jalr, csrSel, ierr, ecall, ebreak, wfi, ret,
                PC, Instr, Mem_WrAddr, Mem_WrData, wea, ReadData, Result, InstrD, MemWrite,
                Jump, Branch, MemWriteM, is_mem_accessM, funct3, PCW, ALUResultW, WriteDataW, ReadDataW,
                apb_done);

endmodule