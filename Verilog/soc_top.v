
// soc_top.v - Top-level module for the RISC-V SoC
module soc_top (
    // clock and reset
    input clk, rst_n,
    input pclk, presetn,

    // peripheral outputs
    output pwm_out0, pwm_out1,
    inout [31:0] gpio_pad,
    input rx,
    output tx,
    inout [3:0] qspi_io,
    output qspi_sck,
    output qspi_cs_n,
    output cpu_resetn_w
);

wire [31:0] PC, Result, ALUResult, DataAdr, WriteData_M;
wire [31:0] WriteData, ReadData;
wire MemWrite;

// GPIO IOBUFs
wire [31:0] gpio_in_w, gpio_out_w, gpio_oe_w;
genvar gi;
generate
    for (gi = 0; gi < 32; gi = gi + 1) begin : GPIO_IOBUF
        IOBUF gpio_iobuf (
            .I (gpio_out_w[gi]),  // value to drive out
            .O (gpio_in_w[gi]),   // value sampled in
            .IO(gpio_pad[gi]),    // physical bidirectional pin
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
            .T (~qspi_io_oe_w)     // all 4 pins share the same OE direction
        );
    end
endgenerate

soc_io soc_u (
    .clk(clk), .rst_n(rst_n),
    .pclk(pclk), .presetn(presetn),
    .PCW(PC), .Result(Result), .ALUResult(ALUResult), .DataAdr(DataAdr),
    .WriteData_M(WriteData_M), .WriteDataW(WriteData), .ReadDataW(ReadData),
    .MemWrite(MemWrite),
    .pwm_out0(pwm_out0), .pwm_out1(pwm_out1),
    .gpio_in(gpio_in_w), .gpio_out(gpio_out_w), .gpio_oe(gpio_oe_w),
    .rx(rx), .tx(tx),
    .qspi_io_in(qspi_io_in_w), .qspi_io_out(qspi_io_out_w), .qspi_io_oe(qspi_io_oe_w),
    .qspi_sck(qspi_sck), .qspi_cs_n(qspi_cs_n), .cpu_resetn_w(cpu_resetn_w)
);

endmodule