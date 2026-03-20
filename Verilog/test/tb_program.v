`timescale 1 ns/1 ns

// Test the RISC-V processor for pipelined cpu with a simple program that adds 10 to a value in memory and halts
module tb_program;

// registers to send data
reg clk;
reg reset;
reg Ext_MemWrite;
reg [31:0] Ext_WriteData, Ext_DataAdr;

// Wire Ouputs from Instantiated Modules
wire [31:0] WriteData, DataAdr, ReadData;
wire MemWrite;
wire [31:0] PCW, Result, DataAdrW, WriteDataW, ReadDataW;
// Initialize Top Module
riscv_cpu uut (clk, reset, Ext_MemWrite, Ext_WriteData, Ext_DataAdr, MemWrite, WriteData, DataAdr, ReadData, PCW, Result, DataAdrW, WriteDataW, ReadDataW);

// generate clock to sequence tests
always begin
    clk <= 0; # 8; clk <= 1; # 8;
end

initial begin
    $dumpfile("./Verilog/dumps/tb_program.vcd");
    $dumpvars(0, tb_program);
    reset = 0;  // Active-low reset
    Ext_MemWrite = 0; Ext_DataAdr = 32'b0; Ext_WriteData = 32'b0;
    # 100; // wait for reset to propagate and mem init

    @(negedge clk);
    Ext_MemWrite = 1; Ext_DataAdr = 32'h00001000; Ext_WriteData = 32'h0000000A;
    @(posedge clk); @(posedge clk);

    Ext_MemWrite = 0; Ext_DataAdr = 32'h00000000; Ext_WriteData = 32'b0;
    @(posedge clk);

    @(negedge clk);
    Ext_MemWrite = 1; Ext_DataAdr = 32'h00001004; Ext_WriteData = 32'h00000001;
    @(posedge clk); @(posedge clk);

    reset = 1;
    Ext_MemWrite = 0; Ext_DataAdr = 32'h00000000; Ext_WriteData = 32'b0;
    @(posedge clk);

    #100000;
    $display("Worst Case simulation time reached, Problem with the design :(");
    $finish;
end

always @(negedge clk) begin
    // debug info
    // $display("PCF = %h, Instr = %h, WriteData = %h, ReadAdr = %h, Result =  %h", uut.rvpl.dp.PCF, uut.rvpl.dp.Instr, WriteData, DataAdr, Result);
    if (MemWrite && reset) begin
        if (DataAdr == 32'h00001004) begin
            $display("Memory write detected at address 0x00001004");
            $display("Test Info: Value %d written to memory", $signed(WriteData));
        end
        if (DataAdr == 32'h00001008) begin
            $display("Memory write detected at address 0x00001008");
            if (WriteData == 32'd1) begin
                $display("Test passed: Program halted successfully");
            end else begin
                $display("Test failed: Program did not halt correctly %d", WriteData);
            end
            $finish;
        end
    end
end

endmodule