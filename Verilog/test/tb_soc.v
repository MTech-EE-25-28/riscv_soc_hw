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
reg  [4:0]  interrupt;
// Debug outputs
wire [31:0] PC, Result, ALUResult, DataAdr, WriteData, ReadData;
wire        MemWrite, pwm_out0, pwm_out1;

soc dut (
    clk, reset, pclk, presetn, pready, prdata, pslverr, paddr, psel, penable, pwrite, pwdata,
    PC, Result, ALUResult, DataAdr, WriteData, ReadData, MemWrite, pwm_out0, pwm_out1
);

always #10 clk = ~clk; // 50MHz clock

initial begin
    $dumpfile("./Verilog/dumps/tb_soc.vcd");
    $dumpvars(0, tb_soc);
    // Initialize signals
    clk = 0; reset = 0; pclk = 0; presetn = 0; pready = 0; prdata = 0; pslverr = 0; interrupt = 0;
    #100; // Wait for reset to propagate

    reset = 1; presetn = 1; // Release reset
    #10000;
    $display("Testbench timeout. Something might be wrong.");
    $finish;
end

integer skip=0;
always @(negedge clk) begin
    // debug info
    // if (PC >= 32'h44 && PC <= 32'he8) $display("mepc=%h",dut.rvpl.dp.csr.mepc);
    if (MemWrite && reset) begin
        if (DataAdr == 32'h00001000) begin
            skip = skip + 1; // write first time 0, then 108
            $display("Memory operation detected at address 0x00001000");
            if (skip > 1) begin
                if (Result == 32'd108) begin
                    $display("Test passed: Program halted successfully");
                end else begin
                    $display("Test failed: Program did not halt correctly %d", WriteData);
                end
                $finish;
            end
        end
    end
end

endmodule