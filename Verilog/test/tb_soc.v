`timescale 1ns / 1ps
// testbench to verify the functionality of the RISC-V SoC
module tb_soc;

reg clk, reset;
// APB signals
reg         pclk;
reg         presetn;
reg         pready;
reg  [31:0] prdata;
reg         pslverr;
wire [31:0] paddr;
wire [4:0]  psel;
wire        penable;
wire        pwrite;
wire [31:0] pwdata;
// Debug outputs
wire [31:0] PC, Result, ALUResult, DataAdr, WriteData, ReadData;
wire        MemWrite, pwm_out0, pwm_out1;
// peripheral interfaces
wire [31:0] gpio_pad;
wire        tx, rx;
assign rx = tx; // UART loopback: tx idles high, so rx never floats

soc dut (
    clk, reset, pclk, presetn, pready, prdata, pslverr, paddr, psel, penable, pwrite, pwdata,
    PC, Result, ALUResult, DataAdr, WriteData, ReadData, MemWrite,
    pwm_out0, pwm_out1, gpio_pad, rx, tx
);

always #10 clk = ~clk; // 50MHz clock
always #10 pclk = ~pclk; // APB/peripheral clock (same frequency)

initial begin
    $dumpfile("./Verilog/dumps/tb_soc.vcd");
    $dumpvars(0, tb_soc);
    // Initialize signals
    clk = 0; reset = 0; pclk = 0; presetn = 0; pready = 0; prdata = 0; pslverr = 0;
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
            skip = skip + 1; // write first time 0, then 108
            if (skip > 1) begin
                if (Result == 32'd108 && skip == 2) begin
                    $display("Timer Interrupt Triggered and Handled Successfully! Result = %d", Result);
                end else if (Result == 32'd111) begin
                    $display("UART Transmission completed Successfully! Result = %d", Result);
                    #10000; $finish;
                end
            end
        end
    end
end

endmodule