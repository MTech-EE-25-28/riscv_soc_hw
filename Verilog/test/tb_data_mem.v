`timescale 1ns/1ps

module tb_data_mem;

reg clk;
reg reset;
reg [3:0] wea;
reg [31:0] addr;
reg [31:0] wr_data;
wire [31:0] rd_data;

// Instantiate DUT
data_mem uut (
    .clk(clk), .wea(wea), .addr(addr),
    .wr_data(wr_data), .rd_data(rd_data)
);

// Clock generation
always #7 clk = ~clk;

// Task for writing
task write_mem;
input [31:0] address;
input [31:0] data;
input [3:0]  write_enable;
begin
    @(negedge clk);
    addr = address;
    wr_data = data;
    wea = write_enable;

    @(posedge clk);   // perform write

    @(negedge clk);
    wea = 4'b0000;    // disable write
end
endtask

// Task for reading
task read_mem;
input [31:0] address;
begin
    @(negedge clk);
    addr = address;

    @(posedge clk);   // synchronous read
    @(posedge clk);   // data available

    $display("Time=%0t | Address=%h | Read Data=%h", $time, address, rd_data);
end
endtask

initial begin
    $dumpfile("./Verilog/dumps/tb_data_mem.vcd");
    $dumpvars(0, tb_data_mem);
    // Initialize
    clk = 0; reset = 0; wea = 0; addr = 0; wr_data = 0;

    // Reset sequence
    #28;
    reset = 1; #100; // may be post-synthesis mem init delay?

    // TEST 1 : Full Word Write (SW)
    write_mem(32'h00000004, 32'hDEADBEEF, 4'b0011);
    read_mem(32'h00000004);

    // TEST 2 : Byte Write (SB)
    write_mem(32'h00000008, 32'h000000AA, 4'b0001);
    read_mem(32'h00000008);

    // TEST 3 : Half Word Write (SH)
    write_mem(32'h0000000C, 32'h0000BBBB, 4'b0011);
    read_mem(32'h0000000C);

    write_mem(32'h0000000F, 32'hAA00BBBB, 4'b1011);
    read_mem(32'h0000000F);

    write_mem(32'h00000004, 32'hAACCBBBB, 4'b1111);
    read_mem(32'h00000004);

    // TEST 4 : Read Different Address
    read_mem(32'h00000008);

    #50;
    $finish;

end

endmodule