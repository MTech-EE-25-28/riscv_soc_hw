// soc.v - SoC wrapper with inout GPIO and QSPI ports (synthesizable top-level)
// Instantiates soc_io (split in/out/oe) and bridges via IOBUF primitives.
// Use this as the top-level in Vivado when not using soc_top.v.
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
    output wire        tx,
    inout  wire [3:0]  qspi_io,
    output wire        qspi_sck,
    output wire        qspi_cs_n
);

// GPIO IOBUFs
wire [31:0] gpio_in_w, gpio_out_w, gpio_oe_w;
genvar gi;
generate
    for (gi = 0; gi < 32; gi = gi + 1) begin : GPIO_IOBUF
        IOBUF gpio_iobuf (
            .I (gpio_out_w[gi]),
            .O (gpio_in_w[gi]),
            .IO(gpio_pad[gi]),
            .T (~gpio_oe_w[gi])   // 0 = drive, 1 = high-Z
        );
    end
endgenerate

// QSPI IOBUFs
wire [3:0] qspi_io_in_w, qspi_io_out_w;
wire       qspi_io_oe_w;
genvar qi;
generate
    for (qi = 0; qi < 4; qi = qi + 1) begin : QSPI_IOBUF
        IOBUF qspi_iobuf (
            .I (qspi_io_out_w[qi]),
            .O (qspi_io_in_w[qi]),
            .IO(qspi_io[qi]),
            .T (~qspi_io_oe_w)
        );
    end
endgenerate

// Core SoC
soc_io soc_core (
    .clk(clk), .rst_n(rst_n),
    .pclk(pclk), .presetn(presetn),
    .PCW(PCW), .Result(Result), .ALUResult(ALUResult), .DataAdr(DataAdr),
    .WriteData_M(WriteData_M), .WriteDataW(WriteDataW), .ReadDataW(ReadDataW),
    .MemWrite(MemWrite),
    .pwm_out0(pwm_out0), .pwm_out1(pwm_out1),
    .gpio_in(gpio_in_w), .gpio_out(gpio_out_w), .gpio_oe(gpio_oe_w),
    .rx(rx), .tx(tx),
    .qspi_io_in(qspi_io_in_w), .qspi_io_out(qspi_io_out_w), .qspi_io_oe(qspi_io_oe_w),
    .qspi_sck(qspi_sck), .qspi_cs_n(qspi_cs_n)
);

endmodule

