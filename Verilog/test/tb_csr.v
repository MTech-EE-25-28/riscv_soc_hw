`timescale 1 ns/1 ns

// Test the RISC-V processor for CSR instructions
module tb_csr;

// registers to send data
reg clk;
reg reset;
reg Ext_MemWrite;
reg [31:0] Ext_WriteData, Ext_DataAdr;

// Wire Outputs from Instantiated Modules
wire [31:0] WriteData, DataAdr, ReadData;
wire MemWrite;
wire [31:0] PCW, Result, DataAdrW, WriteDataW, ReadDataW;

// Initialize Top Module
riscv_cpu uut (clk, reset, Ext_MemWrite, Ext_WriteData, Ext_DataAdr, MemWrite, WriteData, DataAdr, ReadData, PCW, Result, DataAdrW, WriteDataW, ReadDataW);

integer fault_instrs = 0, i = 0, flag = 0;
reg [31:0] last_pcw = 32'hFFFFFFFF; // guard: only check once per unique PCW

localparam CSR_MISA     =   32'h00;
localparam CSR_MCYCLEL  =   32'h04;
localparam CSR_MCYCLEH  =   32'h08;
localparam CSR_INSTRETL =   32'h0C;
localparam CSR_INSTRETH =   32'h10;
localparam CSR_CSRRWD   =   32'h14;
localparam CSR_CSRRWS   =   32'h18;
localparam CSR_CSRRSD   =   32'h1C;
localparam CSR_CSRRSS   =   32'h20;
localparam CSR_CSRRCD   =   32'h24;
localparam CSR_CSRRCS   =   32'h28;
localparam CSR_CSRRWID  =   32'h2C;
localparam CSR_CSRRWIS  =   32'h30;
localparam CSR_CSRRSID  =   32'h34;
localparam CSR_CSRRSIS  =   32'h38;
localparam CSR_CSRRCID  =   32'h3C;
localparam CSR_CSRRCIS  =   32'h40;

always begin
    clk <= 0; #8; clk <= 1; #8;
end

initial begin

end

endmodule