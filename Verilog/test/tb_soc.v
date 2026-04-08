`timescale 1ns / 1ps
// testbench to verify the functionality of the RISC-V SoC
module tb_soc;

reg clk, reset;
// APB signals
reg pclk, presetn;
// Debug outputs
wire [31:0] PC, Result, ALUResult, DataAdr, WriteData_M, WriteData, ReadData;
wire        MemWrite, pwm_out0, pwm_out1;
// peripheral interfaces
wire [31:0] gpio_pad;
wire        tx, rx;
wire [3:0]  qspi_io;
wire        qspi_sck, qspi_cs_n;

assign rx = tx; // UART loopback: tx idles high, so rx never floats

soc dut (
    clk, reset, pclk, presetn,
    PC, Result, ALUResult, DataAdr, WriteData_M, WriteData, ReadData, MemWrite,
    pwm_out0, pwm_out1, gpio_pad, rx, tx, qspi_io, qspi_sck, qspi_cs_n
);

always #10 clk = ~clk; // 50MHz clock
always #10 pclk = ~pclk; // APB/peripheral clock (same frequency)

initial begin
    $dumpfile("./Verilog/dumps/tb_soc.vcd");
    $dumpvars(0, tb_soc);
    // Initialize signals
    clk = 0; reset = 0; pclk = 0; presetn = 0;
    #100; // Wait for reset to propagate

    reset = 1; presetn = 1; // Release reset
    #1000000;
    $display("Testbench timeout.");
    $finish;
end

integer skip=0;
always @(negedge clk) begin
    if (MemWrite && reset) begin
        if (DataAdr == 32'h00001000) begin
            skip = skip + 1;
            if (skip > 1) begin
                if (WriteData_M == 32'd108) begin
                    $display("Timer Interrupt Triggered and Handled Successfully! Result = %d", WriteData_M);
                end else if (WriteData_M == 32'd111) begin
                    $display("UART Transmission completed Successfully! Result = %d", WriteData_M);
                end else if (WriteData_M == 32'd789) begin
                    $display("Timer Loop UART TX done! TEST_LOC = %d", WriteData_M);
                    #10000; $finish;
                end
            end
        end
    end
end

endmodule