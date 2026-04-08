
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
    output qspi_cs_n
);

wire [31:0] PC, Result, ALUResult, DataAdr, WriteData_M;
wire [31:0] WriteData, ReadData;
wire MemWrite;

soc soc_u (
    .clk(clk), .rst_n(rst_n),
    .pclk(pclk), .presetn(presetn),
    .PCW(PC), .Result(Result), .ALUResult(ALUResult), .DataAdr(DataAdr),
    .WriteData_M(WriteData_M), .WriteDataW(WriteData), .ReadDataW(ReadData),
    .MemWrite(MemWrite),
    .pwm_out0(pwm_out0), .pwm_out1(pwm_out1),
    .gpio_pad(gpio_pad),
    .rx(rx), .tx(tx), .qspi_io(qspi_io), .qspi_sck(qspi_sck), .qspi_cs_n(qspi_cs_n)
);

endmodule