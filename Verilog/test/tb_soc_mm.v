`timescale 1ns / 1ps

module tb_soc_mm;

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
wire [31:0] PC, Result, ALUResult, DataAdr, WriteData_M, WriteData, ReadData;
wire        MemWrite, pwm_out0, pwm_out1;
// peripheral interfaces
wire [31:0] gpio_pad;
wire        tx, rx;
assign rx = tx; // UART loopback: tx idles high, so rx never floats

soc dut (
    clk, reset, pclk, presetn, pready, prdata, pslverr, paddr, psel, penable, pwrite, pwdata,
    PC, Result, ALUResult, DataAdr, WriteData_M, WriteData, ReadData, MemWrite,
    pwm_out0, pwm_out1, gpio_pad, rx, tx
);

always #10 clk = ~clk; // 50MHz clock
always #10 pclk = ~pclk; // APB/peripheral clock (same frequency)

initial begin
    $dumpfile("./Verilog/dumps/tb_soc_mm.vcd");
    $dumpvars(0, tb_soc_mm);
    // Initialize signals
    clk = 0; reset = 0; pclk = 0; presetn = 0; pready = 0; prdata = 0; pslverr = 0;
    #100; // Wait for reset to propagate

    reset = 1; presetn = 1; // Release reset
    #10000000;
    $display("Testbench timeout.");
    $finish;
end

integer skip_1=0, skip_2=0;
always @(negedge clk) begin
    // debug info
    // $display("PCF = %h, Instr = %h, WriteData = %h, ReadAdr = %h, Result =  %h", uut.rvpl.dp.PCF, uut.rvpl.dp.Instr, WriteData, DataAdr, Result);
    if (MemWrite && reset) begin
        if (DataAdr == 32'h00001004) begin
            skip_1 = skip_1 + 1;
            if (skip_1 > 1) begin
                $display("Memory write detected at address 0x00001004");
                $display("Test Info: Value %d written to memory", $signed(WriteData_M));
            end
        end
        if (DataAdr == 32'h00001008) begin
            skip_2 = skip_2 + 1;
            if (skip_2 > 1) begin
                $display("Memory write detected at address 0x00001008");
                if (WriteData_M == 32'd1) begin
                    $display("Test passed: Program halted successfully");
                end else begin
                    $display("Test failed: Program did not halt correctly %d", WriteData_M);
                end
                $finish;
            end
        end
    end
end

endmodule