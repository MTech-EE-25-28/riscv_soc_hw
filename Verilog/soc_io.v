
// soc_io.v - SoC core with split in/out/oe GPIO and QSPI ports (no inout)
module soc_io (
    input         clk, rst_n,

    // APB Interface
    input  wire        pclk,
    input  wire        presetn,
    // Debug outputs
    output wire [31:0] PCW, Result, ALUResult, DataAdr, WriteData_M, WriteDataW, ReadDataW,
    output wire        MemWrite,
    // peripheral interfaces
    output wire        pwm_out0, pwm_out1,
    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out,
    output wire [31:0] gpio_oe,
    input  wire        rx,
    output wire        tx,
    input  wire [3:0]  qspi_io_in,
    output wire [3:0]  qspi_io_out,
    output wire        qspi_io_oe,
    output wire        qspi_sck,
    output wire        qspi_cs_n
);

wire [31:0] WriteData;
assign WriteData_M = WriteData;
wire [31:0] Instr;
wire [3:0]  mem_wea;
wire [2:0]  funct3;
wire [4:0]  irq_w;
wire [31:0] PCF, dmem_rdata, cpu_rdata;

// apb_done: 1-cycle pulse from axi_interface (state==WAIT) that overrides
wire apb_done_w;

// ReadData mux: peripheral addresses use APB cpu_rdata, SRAM uses dmem_rdata.
// Use WB-stage address (ALUResultW=ALUResult) so the mux is correct when the
// M-stage has a different instruction (e.g. a bubble after a peripheral load stall).
wire [31:0] ReadData = (ALUResult >= 32'h0000_2000) ? cpu_rdata : dmem_rdata;

// instantiate processor
wire is_mem_access;
riscv_pl rvpl (
    .clk(clk),
    .reset(rst_n),
    .interruptA(irq_w),
    .apb_done(apb_done_w),
    .PC(PCF),
    .Instr(Instr),
    .MemWriteM(MemWrite),
    .is_mem_accessM(is_mem_access),
    .Mem_WrAddr(DataAdr),
    .Mem_WrData(WriteData),
    .wea(mem_wea),
    .ReadData(ReadData),
    .funct3(funct3),
    .PCW(PCW),
    .Result(Result),
    .ALUResultW(ALUResult),
    .WriteDataW(WriteDataW),
    .ReadDataW(ReadDataW)
);

memory_controller mem_ctrl (
    .clk(clk),
    .resetn(rst_n),

    // CPU side
    .PCF(PCF),
    .DataAdr(DataAdr),
    .WriteData(WriteData),
    .mem_wea(mem_wea),
    .MemWrite(MemWrite),
    .is_mem_access(is_mem_access),

    // Outputs to CPU
    .Instr(Instr),
    .dmem_rdata(dmem_rdata),
    .cpu_rdata(cpu_rdata),
    .apb_done(apb_done_w),

    // IRQs
    .irq(irq_w),

    // Peripheral pins
    .pwm_out0(pwm_out0),
    .pwm_out1(pwm_out1),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_oe(gpio_oe),
    .rx(rx),
    .tx(tx),
    .qspi_io_in(qspi_io_in),
    .qspi_io_out(qspi_io_out),
    .qspi_io_oe(qspi_io_oe),
    .qspi_sck(qspi_sck),
    .qspi_cs_n(qspi_cs_n)
);
endmodule

