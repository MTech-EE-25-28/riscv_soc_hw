`timescale 1ns / 1ps
// testbench to verify the functionality of the timer module
module tb_timer;

reg clk, resetn;
reg psel, penable, pwrite;
reg [31:0] paddr;
reg [31:0] pwdata;
wire [31:0] prdata;
wire pready, pslverr;
wire irq, pwm_out0, pwm_out1;

timer dut (
    .clk(clk),
    .resetn(resetn),
    .pclk(clk),
    .presetn(resetn),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .paddr(paddr),
    .pwdata(pwdata),
    .prdata(prdata),
    .pready(pready),
    .pslverr(pslverr),
    .irq(irq),
    .pwm_out0(pwm_out0),
    .pwm_out1(pwm_out1)
);


task apb_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge clk); #1;
        psel=1; pwrite=1; penable=0; paddr=addr; pwdata=data;
        @(posedge clk); #1;
        penable=1;
        @(posedge clk); #1;
        psel=0; penable=0;
    end
endtask

task apb_read(input [31:0] addr);
    begin
        @(posedge clk); #1;
        psel=1; pwrite=0; penable=0; paddr=addr;
        @(posedge clk); #1;
        penable=1;
        @(posedge clk);
        $display("APB READ [%h] = %h", addr, prdata); #1;
        psel=0; penable=0;
    end
endtask

always #10 clk = ~clk; // 50MHz clock

initial begin
    $dumpfile("./Verilog/dumps/tb_timer.vcd");
    $dumpvars(0, tb_timer);
    // Initialize signals
    clk = 0; resetn = 0; psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
    #100; // Wait for reset to propagate

    resetn = 1; // Release reset

    // Simulate some APB transactions
    apb_write(32'h0000_2088, 32'h0000_00FF); // Set OCMR to 255 BEFORE enabling (else irq fires immediately at OCMR=0)
    apb_write(32'h0000_2080, 32'h0000_0007); // Enable timer (timer en + PWM en + irq en)
    #1000; // Let the timer run

    apb_read(32'h0000_2084); // Read TCNT
    wait (irq); // Wait for interrupt
    $display("time: %0t Timer interrupt triggered!", $time);
    @(posedge clk); #1;
    wait (irq); // Wait for interrupt
    $display("time: %0t Timer interrupt triggered!", $time);
    @(posedge clk); #1;
    wait (irq); // Wait for interrupt
    $display("time: %0t Timer interrupt triggered!", $time);

    apb_write(32'h0000_2088, 32'h0FFF_00FF);
    apb_write(32'h0000_2080, 32'h0001_0007);

    #2000;
    $finish;
end

initial begin // testbench timeout
    #20000;
    $display("Testbench timeout. Something might be wrong.");
    $finish;
end

endmodule