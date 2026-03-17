`timescale 1ns / 1ps

module tb_division_top;

reg clk;
reg enable;
reg [31:0] rs1;
reg [31:0] rs2;
reg [2:0] funct3;

wire valid_op_d;
wire [31:0] rd;

division_top uut (
    .clk(clk),
    .rs1(rs1),
    .rs2(rs2),
    .enable(enable),
    .funct3(funct3),
    .valid_op_d(valid_op_d),
    .rd(rd)
);

always #7 clk = ~clk;

initial begin
    $dumpfile("./Verilog/dumps/tb_division_top.vcd");
    $dumpvars(0, tb_division_top);
    clk = 0; enable = 0;

    // Test 1 : DIV
    #20;
    $display("\n=== Test 1: DIV ===");
    rs1 = -32'd6;
    rs2 = 32'd18;
    funct3 = 3'b100;
    enable = 1;

    wait (valid_op_d);

    $display("DIV  : %0d / %0d = %0d (Expected: 0)", $signed(rs1), $signed(rs2), $signed(rd));
    if ($signed(rd) == 0) $display("✓ PASS");
    else $display("✗ FAIL");

    enable = 0;

    // Test 2 : DIVU
    #20;
    $display("\n=== Test 2: DIVU ===");
    rs1 = -32'd6;  // 0xFFFFFFFA = 4294967290
    rs2 = 32'd18;
    funct3 = 3'b101;
    enable = 1;

    wait (valid_op_d);

    $display("DIVU : %0d / %0d = %0d (Expected: 238609293)", rs1, rs2, rd);
    if (rd == 238609293) $display("✓ PASS");
    else $display("✗ FAIL");

    enable = 0;

    // Test 3 : REM
    #20;
    $display("\n=== Test 3: REM ===");
    rs1 = -32'd6;
    rs2 = 32'd18;
    funct3 = 3'b110;
    enable = 1;

    wait (valid_op_d);

    $display("REM  : %0d %% %0d = %0d (Expected: -6)", $signed(rs1), $signed(rs2), $signed(rd));
    enable = 0;

    // Test 4 : REMU
    #20;
    $display("\n=== Test 4: REMU ===");
    rs1 = -32'd6;  // 0xFFFFFFFA = 4294967290
    rs2 = 32'd18;
    funct3 = 3'b111;
    enable = 1;

    wait (valid_op_d);
    $display("REMU : %0d %% %0d = %0d (Expected: 16)", rs1, rs2, rd);
    enable = 0;

    #200;
    $display("\n=== All Tests Complete ===");
    $finish;
end

endmodule