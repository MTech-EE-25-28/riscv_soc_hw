
// riscv_cpu.v - Top Module to test riscv_cpu
module riscv_cpu (
    input         clk, reset,
    input         Ext_MemWrite,
    input  [31:0] Ext_WriteData, Ext_DataAdr,
    output        MemWrite,
    output [31:0] WriteData, DataAdr, ReadData,
    output [31:0] PC, Result, ALUResultW, WriteDataW, ReadDataW
);

wire [31:0] Instr, PCF;
wire [31:0] DataAdr_rv32, WriteData_rv32;
wire [2:0]  funct3;
wire        MemWrite_rv32;
wire [3:0]  wea;

// instantiate processor and memories
riscv_pl rvpl (
    clk, reset, PCF, Instr, MemWrite_rv32, DataAdr_rv32, WriteData_rv32, wea,
    ReadData, Result, funct3, PC, ALUResultW, WriteDataW, ReadDataW
);
instr_mem instrmem (clk, reset, 1'b0, PCF, 32'b0, Instr);
data_mem  datamem  (clk, reset, wea, DataAdr, WriteData, ReadData);

assign MemWrite  = (Ext_MemWrite && !reset) ? 1'b1 : MemWrite_rv32;
assign WriteData = (Ext_MemWrite && !reset) ? Ext_WriteData : WriteData_rv32;
assign DataAdr   = !reset ? Ext_DataAdr : DataAdr_rv32;

endmodule