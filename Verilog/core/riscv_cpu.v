
// riscv_cpu.v - Top Module to test riscv_cpu
module riscv_cpu (
    input         clk, reset,
    input   [4:0] interruptA,
    input         Ext_MemWrite,
    input  [31:0] Ext_WriteData, Ext_DataAdr,
    output        MemWrite,
    output [31:0] WriteData, DataAdr, ReadData,
    output [31:0] PC, Result, ALUResultW, WriteDataW, ReadDataW
);

wire [31:0] Instr, PCF;
wire [31:0] DataAdr_rv32, WriteData_rv32;
wire [3:0]  mem_wea, wea;
wire [2:0]  funct3;
wire        MemWrite_rv32, imem_rst, dmem_rst;

// instantiate processor and memories
riscv_pl rvpl (
    clk, reset, interruptA, PCF, Instr, MemWrite_rv32, DataAdr_rv32, WriteData_rv32, wea,
    ReadData, Result, funct3, PC, ALUResultW, WriteDataW, ReadDataW
);
instr_mem instrmem (clk, 1'b0, PCF, 32'b0, Instr);
data_mem  datamem  (clk, mem_wea, DataAdr, WriteData, ReadData);

assign MemWrite  = Ext_MemWrite ? 1'b1 : MemWrite_rv32;
assign WriteData = Ext_MemWrite ? Ext_WriteData : WriteData_rv32;
assign DataAdr   = Ext_MemWrite ? Ext_DataAdr : DataAdr_rv32;
assign mem_wea   = Ext_MemWrite ? 4'b1111 : wea;

endmodule