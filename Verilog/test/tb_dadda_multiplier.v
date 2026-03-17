`timescale 1ns / 1ps

module tb_dadda_multiplier;

reg clk, enable;
reg [31:0] rs1, rs2;
reg [2:0] funct3;

wire valid_op;
wire [31:0] rd;

dadda_multiplier uut (
    .clk(clk),
    .enable(enable),
    .rs1(rs1),
    .rs2(rs2),
    .funct3(funct3),
    .rd(rd),
    .valid_op(valid_op)
);

// Clock generation
always #10 clk = ~clk;

// Stimulus
initial begin
    $dumpfile("./Verilog/dumps/tb_dadda_multiplier.vcd");
    $dumpvars(0, tb_dadda_multiplier);
    clk = 0; enable = 0;

    rs1 = 0; rs2 = 0; funct3 = 0;
    #20;
    // -------- MUL --------
    @(posedge clk);
    enable = 1;
    rs1 = 32'h0000000A;   // 10
    rs2 = 32'h00000005;   // 5
    funct3 = 3'b000;
    wait(valid_op);

    // -------- MULH --------
    @(posedge clk); @(posedge clk);
    rs1 = 32'hFFFFFFEC;   // -20
    rs2 = 32'h00000003;   // 3
    funct3 = 3'b001;
    wait(valid_op);

    @(posedge clk); @(posedge clk);
    rs1 = 32'hFFFFFFEC;   // -20
    rs2 = 32'h00000003;   // 3
    funct3 = 3'b000;
    wait(valid_op);

    // -------- MULHSU --------
    @(posedge clk); @(posedge clk);
    rs1 = 32'hFFFFFFEC;
    rs2 = 32'h00000004;
    funct3 = 3'b010;
    wait(valid_op);

    // -------- MULHU --------
    @(posedge clk); @(posedge clk);
    rs1 = 32'hFFFFFFFF;
    rs2 = 32'h00000003;
    funct3 = 3'b011;
    wait(valid_op);

    // Stop sending instructions
    repeat(10) @(posedge clk) ;
    enable = 0;

    // Allow pipeline to flush
    repeat(10) @(posedge clk);

    $finish;
end

// Debug print (helps visualize pipeline)
always @(posedge clk) begin
    $monitor("time=%0t rs1=%h rs2=%h funct3=%b rd=%h valid=%b",
             $time, rs1, rs2, funct3, rd, valid_op);
end

endmodule