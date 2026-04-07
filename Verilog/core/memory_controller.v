module memory_controller (
    input  wire        clk,
    input  wire        resetn,

    // CPU side
    input  wire [31:0] PCF,
    input  wire [31:0] DataAdr,
    input  wire [31:0] WriteData,
    input  wire [3:0]  mem_wea,
    input  wire        MemWrite,
    input  wire        is_mem_access,

    // Outputs back to CPU
    output wire [31:0] Instr,
    output wire [31:0] dmem_rdata,
    output wire [31:0] cpu_rdata,
    output wire        apb_done,

    // Peripheral IRQs
    output wire [4:0]  irq,

    // Pads
    output wire        pwm_out0,
    output wire        pwm_out1,
    inout  wire [31:0] gpio_pad,
    input  wire        rx,
    output wire        tx
);

// --------------------------------------------------
// Internal interconnect between memory controller
// and axi_interface
// --------------------------------------------------
wire [31:0] paddr, pwdata, prdata;
wire [4:0]  psel;
wire        penable, pwrite, pready, pslverr;

// --------------------------------------------------
// REGION DECODE
// --------------------------------------------------
wire imem_sel, dmem_sel, periph_sel;

assign imem_sel   = (paddr   >= 32'h0000_0000 && paddr   < 32'h0000_1000);
assign dmem_sel   = (DataAdr >= 32'h0000_1000 && DataAdr < 32'h0000_2000);
assign periph_sel = is_mem_access && (DataAdr >= 32'h0000_2000);

// --------------------------------------------------
// IMEM CONTROL
// Only APB writes can program instruction memory
// --------------------------------------------------
wire imem_wea;
wire [31:0] InstrAddr;

assign imem_wea  = (|psel) && penable && pwrite && imem_sel;
assign InstrAddr = imem_wea ? paddr[31:0]: PCF[31:0];

// --------------------------------------------------
// DMEM CONTROL
// --------------------------------------------------
wire [3:0] dmem_wea;
assign dmem_wea = dmem_sel ? mem_wea : 4'b0000;

// --------------------------------------------------
// MEMORY INSTANCES
// --------------------------------------------------
instr_mem instrmem (
    .clk(clk),
    .wea(imem_wea),
    .instr_addr(InstrAddr),
    .instr_in(pwdata),
    .instr(Instr)
);

data_mem datamem (
    .clk(clk),
    .wea(dmem_wea),
    .addr(DataAdr[31:0]),
    .wr_data(WriteData),
    .rd_data(dmem_rdata)
);

// --------------------------------------------------
// Peripheral request generation
// CPU peripheral accesses go to axi_interface
// --------------------------------------------------
wire [31:0] req_addr, req_wdata;

assign req_addr  = periph_sel ? DataAdr   : 32'hFFFF_FFFF;
assign req_wdata = periph_sel ? WriteData : 32'hFFFF_FFFF;

// --------------------------------------------------
// AXI/APB Interface instance
// --------------------------------------------------
axi_interface apb_if (
    .clk(clk),
    .resetn(resetn),

    // APB interface signals
    .pclk(clk),
    .presetn(resetn),
    .pready(pready),
    .prdata(prdata),
    .pslverr(pslverr),
    .paddr(paddr),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .pwdata(pwdata),

    // CPU-side peripheral request
    .cpu_paddr(req_addr),
    .cpu_wdata(req_wdata),
    .write(MemWrite),
    .apb_done(apb_done),
    .cpu_rdata(cpu_rdata),

    // Peripheral outputs
    .irq(irq),
    .pwm_out0(pwm_out0),
    .pwm_out1(pwm_out1),
    .gpio_pad(gpio_pad),
    .rx(rx),
    .tx(tx)
);

endmodule