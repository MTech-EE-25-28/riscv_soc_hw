
// soc.v - Top Module to interface with all components of the RISC-V SoC
module soc (
    input         clk, rst_n,

    // APB Interface
    input  wire        pclk,
    input  wire        presetn,
    // Debug outputs
    output wire [31:0] PCW, Result, ALUResult, DataAdr, WriteData_M, WriteDataW, ReadDataW,
    output wire        MemWrite,
    // peripheral interfaces
    output wire        pwm_out0, pwm_out1,
    inout  wire [31:0] gpio_pad,
    input  wire        rx,
    output wire        tx
);

wire [31:0] WriteData, InstrAddr;
assign WriteData_M = WriteData;
wire [31:0] req_addr, req_wdata;
wire [31:0] Instr, paddr, prdata;
wire [3:0]  mem_wea, dmem_wea;
wire [2:0]  funct3;
wire        imem_wea, pwrite, penable, pslverr, pready;
wire [4:0]  irq_w, psel;
wire [31:0] PCF, dmem_rdata, cpu_rdata, pwdata;

// apb_done: 1-cycle pulse from axi_interface (state==WAIT) that overrides
wire apb_done_w;

// ReadData mux: peripheral addresses use APB cpu_rdata, SRAM uses dmem_rdata.
// Use WB-stage address (ALUResultW=ALUResult) so the mux is correct when the
// M-stage has a different instruction (e.g. a bubble after a peripheral load stall).
wire [31:0] ReadData = (ALUResult >= 32'h0000_2000) ? cpu_rdata : dmem_rdata;

// instantiate processor
riscv_pl rvpl (
    clk, rst_n, irq_w, apb_done_w, PCF, Instr, MemWrite, DataAdr, WriteData, mem_wea,
    ReadData, funct3, PCW, Result, ALUResult, WriteDataW, ReadDataW
);

// address decoding for memory access
assign imem_wea = (paddr >= 32'h0000_0000 && paddr < 32'h0000_1000) ? 1'b1 : 1'b0;
assign dmem_wea = (DataAdr >= 32'h0000_1000 && DataAdr < 32'h0000_2000) ? mem_wea : 4'b0000;

assign InstrAddr = imem_wea ? paddr : PCF;
// instantiate memories
instr_mem instrmem (clk, imem_wea, InstrAddr, pwdata, Instr);
data_mem  datamem  (clk, dmem_wea, DataAdr, WriteData, dmem_rdata);
// happens at Memory stage
assign req_addr = (DataAdr >= 32'h0000_2000) ? DataAdr : 32'hFFFF_FFFF;
assign req_wdata = (DataAdr >= 32'h0000_2000) ? WriteData : 32'hFFFF_FFFF;

// instantiate APB interface
axi_interface apb_if (
    clk, rst_n, clk, rst_n, pready, prdata, pslverr,
    paddr, psel, penable, pwrite, pwdata,
    req_addr, req_wdata, MemWrite, apb_done_w, cpu_rdata, irq_w,
    pwm_out0, pwm_out1, gpio_pad, rx, tx
);

endmodule