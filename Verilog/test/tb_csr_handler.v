`timescale 1ns / 1ps

module tb_csr_handler;


reg clk, reset, ivalid;
reg         csr_write_en;
reg   [1:0] csr_type;
reg  [11:0] csr_addr;
reg  [31:0] csr_write_data;

wire [31:0] csr_read_data;

csr_handler csr (
    clk, reset, ivalid, csr_write_en, csr_type,
    csr_addr, csr_write_data, csr_read_data
);

// clock generation
always #7 clk = ~clk;

initial begin

    $dumpfile("./Verilog/dumps/tb_csr_handler.vcd");
    $dumpvars(0, tb_csr_handler);
    // Initialize
    clk = 0; reset = 0; ivalid = 0; csr_type = 0;
    csr_write_en = 0; csr_addr = 0; csr_write_data = 0;

    // reset
    # 28;
    reset = 1; #100;
    @(posedge clk);
    csr_addr = 12'h301; @(posedge clk); // misa
    @(posedge clk);
    csr_addr = 12'hB00; @(posedge clk); // mcyclel
    @(posedge clk);
    csr_addr = 12'hB80; @(posedge clk); // mcycleh
    @(posedge clk);
    repeat (5) @(posedge clk);
    csr_addr = 12'hB00; @(posedge clk); // mcyclel
    @(posedge clk);
    csr_addr = 12'hB80; @(posedge clk); // mcycleh
    @(posedge clk);

    csr_write_en = 1; csr_addr = 12'h300; csr_write_data = 32'hdeadbeef; // write mstatus
    @(posedge clk); csr_type = 2'b11;
    csr_write_en = 1; csr_addr = 12'h301; csr_write_data = 32'hdeadbeef; // write mstatus
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $finish;
end

initial begin
    $monitor("time=%0t csr_addr=%h, csr_read_data=%h",
            $time, csr_addr, csr_read_data);
end

endmodule