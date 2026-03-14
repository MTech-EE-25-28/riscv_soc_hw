`timescale 1 ns/1 ns

module tb_riscv_top;

reg clk;
reg e_rst;

wire reset;
wire [1:0] state;
wire [31:0] debug_reg0, debug_reg1;

riscv_top uut (
    clk, e_rst, reset, state,
    debug_reg0, debug_reg1
);

always begin
    clk <= 0; # 8; clk <= 1; # 8;
end

initial begin
    $dumpfile("./Verilog/dumps/tb_riscv_top.vcd");
    $dumpvars(0, tb_riscv_top);
    e_rst = 0; # 100; // wait for reset to propagate and mem init
    e_rst = 1;
    $monitor("Time: %0t | State: %b | Debug Regs: %d %d", $time, state, debug_reg0, debug_reg1);
    #10000;
    $display("Simulation timeout");
    $finish;
end


endmodule