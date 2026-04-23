`timescale 1ns / 1ps
// testbench to verify the functionality of the timer module
module tb_timer;

reg clk, resetn;
reg psel, penable, pwrite;
reg [31:0] paddr;
reg [31:0] pwdata;
wire [31:0] prdata;
wire pready, pslverr;
wire irq, pwm_out0, pwm_out1, pwm_out2;

// Register addresses
localparam BASE_ADDR  = 32'h0000_2080;
localparam TCCR_ADDR  = BASE_ADDR;           // BASE + 0x00
localparam TCNT_ADDR  = BASE_ADDR + 32'h04;  // BASE + 0x04
localparam TCNTF_ADDR = BASE_ADDR + 32'h08;  // BASE + 0x08
localparam OCMR_ADDR  = BASE_ADDR + 32'h0C;  // BASE + 0x0C
localparam OCMRF_ADDR = BASE_ADDR + 32'h10;  // BASE + 0x10
localparam TIRQ_ADDR  = BASE_ADDR + 32'h14;  // BASE + 0x14

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
    .pwm_out1(pwm_out1),
    .pwm_out2(pwm_out2)
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
    #50;

    $display("\n=== Timer 0 Test (16-bit) ===");
    // Test Timer 0: 16-bit timer with compare match and PWM
    apb_write(OCMR_ADDR, 32'h0000_00FF); // Set OCMR0 = 255
    apb_write(TCCR_ADDR, 32'h0000_0007); // Enable Timer0 + PWM0 + IRQ0
    #6000; // Let timer run

    apb_read(TCNT_ADDR);  // Read counter value
    apb_read(TIRQ_ADDR);  // Read interrupt flags
    $display("Timer 0 PWM: %b, IRQ: %b", pwm_out0, irq);

    apb_write(TCCR_ADDR, 32'h0000_0000); // Disable Timer0
    #100;

    $display("\n=== Timer 1 Test (16-bit) ===");
    // Test Timer 1: 16-bit timer with compare match and PWM
    apb_write(OCMR_ADDR, 32'h01FF_0000); // Set OCMR1 = 511
    apb_write(TCCR_ADDR, 32'h0000_0038); // Enable Timer1 + PWM1 + IRQ1
    #12000; // Let timer run

    apb_read(TCNT_ADDR);  // Read counter value (both timers)
    apb_read(TIRQ_ADDR);  // Read interrupt flags
    $display("Timer 1 PWM: %b, IRQ: %b", pwm_out1, irq);

    apb_write(TCCR_ADDR, 32'h0000_0000); // Disable Timer1
    #100;

    $display("\n=== Timer 2 Test (32-bit) ===");
    // Test Timer 2: 32-bit timer with compare match and PWM
    apb_write(OCMRF_ADDR, 32'h0000_03FF); // Set OCMRF = 1023
    apb_write(TCCR_ADDR, 32'h0000_01C0);  // Enable Timer2 + PWM2 + IRQ2
    #25000; // Let timer run

    apb_read(TCNTF_ADDR); // Read 32-bit counter value
    apb_read(TIRQ_ADDR);  // Read interrupt flags
    $display("Timer 2 PWM: %b, IRQ: %b", pwm_out2, irq);

    apb_write(TCCR_ADDR, 32'h0000_0000); // Disable Timer2
    #100;

    $display("\n=== All Timers Concurrent Test ===");
    // Test all timers running simultaneously
    apb_write(OCMR_ADDR,  32'h00FF_00FF); // Set OCMR0=255, OCMR1=255
    apb_write(OCMRF_ADDR, 32'h0000_01FF); // Set OCMRF=511
    apb_write(TCCR_ADDR,  32'h0000_01FF); // Enable all timers + PWM + IRQ
    #12000; // Let all timers run

    apb_read(TCNT_ADDR);  // Read Timer 0 & 1 counters
    apb_read(TCNTF_ADDR); // Read Timer 2 counter
    apb_read(TIRQ_ADDR);  // Read all interrupt flags
    $display("All PWMs: T0=%b, T1=%b, T2=%b, IRQ=%b", pwm_out0, pwm_out1, pwm_out2, irq);

    apb_write(TCCR_ADDR, 32'h0000_0000); // Disable all timers
    #100;

    $display("\n=== Interrupt Flag Test ===");
    // Test interrupt generation on compare match
    apb_write(OCMR_ADDR, 32'h0064_0032); // OCMR0=50, OCMR1=100
    apb_write(TCCR_ADDR, 32'h0000_0025); // Timer0+IRQ0, Timer1+IRQ1 (no PWM)

    #1500; // Wait for compare match
    apb_read(TIRQ_ADDR);  // Should show interrupt flags set

    apb_write(TCCR_ADDR, 32'h0000_0000); // Disable timers (clears TIRQ)
    #50;
    apb_read(TIRQ_ADDR);  // Should be cleared

    #1000;
    $display("\n=== Test Complete ===");
    $finish;
end

initial begin // testbench timeout
    #100000;
    $display("Testbench timeout. Something might be wrong.");
    $finish;
end

endmodule