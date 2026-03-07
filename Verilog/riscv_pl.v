
// riscv_pl.v - Pipelined RISC-V CPU Processor
module riscv_pl (
    input         clk, reset,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWriteM,
    output [31:0] Mem_WrAddr, Mem_WrData,
    output  [3:0] wea,
    input  [31:0] ReadData,
    output [31:0] Result,
    output  [2:0] funct3,
    output [31:0] PCW, ALUResultW, WriteDataW, ReadDataW
);

wire         ALUSrc, RegWrite, Jump, Jalr, Branch, MemWrite;
wire  [1:0]  ResultSrc, ImmSrc;
wire  [3:0]  ALUControl;
wire [31:0]  InstrD;

controller  c   (InstrD[6:0], InstrD[14:12], InstrD[30],
                ResultSrc, MemWrite, ALUSrc, RegWrite, Jump, Jalr,
                ImmSrc, ALUControl, Branch);

datapath    dp  (clk, reset, ResultSrc,
                ALUSrc, RegWrite, ImmSrc, ALUControl, Jalr,
                PC, Instr, Mem_WrAddr, Mem_WrData, wea, ReadData, Result, InstrD, MemWrite, Jump, Branch, MemWriteM, funct3, PCW, ALUResultW, WriteDataW, ReadDataW);

endmodule