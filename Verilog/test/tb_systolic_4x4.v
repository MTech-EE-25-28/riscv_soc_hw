`timescale 1ns / 1ps

module tb_systolic_4x4;

reg clk, reset;

reg [31:0] A1, A2, A3, A4;
reg [31:0] B1, B2, B3, B4;

wire [63:0] C11,C12,C13,C14;
wire [63:0] C21,C22,C23,C24;
wire [63:0] C31,C32,C33,C34;
wire [63:0] C41,C42,C43,C44;

systolic_4x4 dut(
    clk, reset,
    A1,A2,A3,A4,
    B1,B2,B3,B4,
    C11,C12,C13,C14,
    C21,C22,C23,C24,
    C31,C32,C33,C34,
    C41,C42,C43,C44
);

// Clock
always #5 clk = ~clk;

initial begin
    $dumpfile("./Verilog/dumps/tb_systolic_4x4.vcd");
    $dumpvars(0, tb_systolic_4x4);
    clk = 0; reset = 1;
    A1=0;A2=0;A3=0;A4=0;
    B1=0;B2=0;B3=0;B4=0;

    #10 reset = 0;

    // =========================
    // SKEWED INPUT STREAMING
    // =========================

    // Cycle 0
    A1=1; A2=0; A3=0; A4=0;
    B1=1; B2=0; B3=0; B4=0;
    #10;

    // Cycle 1
    A1=2; A2=5; A3=0; A4=0;
    B1=5; B2=2; B3=0; B4=0;
    #10;

    // Cycle 2
    A1=3; A2=6; A3=9; A4=0;
    B1=9; B2=6; B3=3; B4=0;
    #10;

    // Cycle 3
    A1=4; A2=7; A3=10; A4=13;
    B1=13; B2=10; B3=7; B4=4;
    #10;

    // Cycle 4
    A1=0; A2=8; A3=11; A4=14;
    B1=0; B2=14; B3=11; B4=8;
    #10;

    // Cycle 5
    A1=0; A2=0; A3=12; A4=15;
    B1=0; B2=0; B3=15; B4=12;
    #10;

    // Cycle 6
    A1=0; A2=0; A3=0; A4=16;
    B1=0; B2=0; B3=0; B4=16;
    #10;

    // Flush cycles
    A1=0;A2=0;A3=0;A4=0;
    B1=0;B2=0;B3=0;B4=0;

    #100;

    // Display results
    $display("Result Matrix C:");
    $display("%d %d %d %d", C11, C12, C13, C14);
    $display("%d %d %d %d", C21, C22, C23, C24);
    $display("%d %d %d %d", C31, C32, C33, C34);
    $display("%d %d %d %d", C41, C42, C43, C44);

    $finish;
end

endmodule