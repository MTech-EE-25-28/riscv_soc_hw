
// soc.v - Top Module to interface with all components of the RISC-V SoC
module soc (
    input         clk, rst_n,

    // APB Interface
    input  wire        pclk,
    input  wire        presetn,
    input  wire        pready,
    input  wire [31:0] prdata,
    input  wire        pslverr,
    output wire [31:0] paddr,
    output wire [4:0]  psel,
    output wire        penable,
    output wire        pwrite,
    output wire [31:0] pwdata,

    // Debug outputs
    output wire [31:0] PCW, Result, ALUResult, DataAdr, WriteDataW, ReadDataW,
    output wire        MemWrite,
    output wire        pwm_out0, pwm_out1,
    // GPIO pads
    inout  wire [31:0] gpio_pad
);

wire [31:0] WriteData, InstrAddr;
wire [31:0] req_addr, req_wdata;
wire [31:0] Instr;
wire [3:0]  mem_wea, dmem_wea;
wire [2:0]  funct3;
wire        imem_wea;
wire [4:0]  irq_w;
wire [31:0] PCF, dmem_rdata, cpu_rdata;
wire        apb_stall; // stall CPU while APB transaction is in progress

// ReadData mux: peripheral addresses come from APB cpu_rdata, dmem otherwise
wire [31:0] ReadData = (DataAdr >= 32'h0000_2000) ? cpu_rdata : dmem_rdata;

// instantiate processor
riscv_pl rvpl (
    clk, rst_n, irq_w, apb_stall, PCF, Instr, MemWrite, DataAdr, WriteData, mem_wea,
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
    req_addr, req_wdata, MemWrite, apb_stall, cpu_rdata, irq_w, pwm_out0, pwm_out1, gpio_pad
);

endmodule