`timescale 1ns / 1ps
// Testbench for gpio.v — exercises APB write/read and tristate behaviour
// Register map (BASE = 0x0000_20C0):
//   GDIR  0x0000_20C0  direction register  (1=output, 0=input)
//   GDAT  0x0000_20C4  data register       (write: drive output; read: pin state)

module tb_gpio;

// DUT signals
reg         clk, resetn;
reg         psel, penable, pwrite;
reg  [31:0] paddr, pwdata;
wire [31:0] prdata;
wire        pready, pslverr, irq;

// Split GPIO ports (gpio.v now uses in/out/oe instead of inout)
wire [31:0] gpio_in_w, gpio_out_w, gpio_oe_w;

// Simulated bidirectional pad — models IOBUF tristate behaviour in TB
wire [31:0] gpio_pad;

// TB-side tristate drive onto gpio_pad
reg  [31:0] gpio_drive;
reg  [31:0] gpio_drive_en;

genvar i;
generate
    for (i = 0; i < 32; i = i + 1) begin : GPIO_PAD_MODEL
        // TB drives pad when gpio_drive_en[i]=1
        assign gpio_pad[i] = gpio_drive_en[i] ? gpio_drive[i] : 1'bz;
        // DUT drives pad when gpio_oe_w[i]=1 (output direction)
        assign gpio_pad[i] = gpio_oe_w[i] ? gpio_out_w[i] : 1'bz;
    end
endgenerate
// Pad value feeds back into DUT's input port
assign gpio_in_w = gpio_pad;

// DUT instantiation
gpio dut (
    .clk(clk),       .resetn(resetn),
    .pclk(clk),      .presetn(resetn),
    .psel(psel),     .penable(penable), .pwrite(pwrite),
    .paddr(paddr),   .pwdata(pwdata),
    .prdata(prdata), .pready(pready),   .pslverr(pslverr),
    .irq(irq),
    .gpio_in(gpio_in_w), .gpio_out(gpio_out_w), .gpio_oe(gpio_oe_w)
);

always #10 clk = ~clk; // 50 MHz

// ---- APB tasks (matching tb_timer.v style) ----

task apb_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge clk); #1;
        psel=1; pwrite=1; penable=0; paddr=addr; pwdata=data;
        @(posedge clk); #1;
        penable=1;
        @(posedge clk); #1;
        psel=0; penable=0; pwrite=0;
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

// ---- Test sequence ----

initial begin
    $dumpfile("./Verilog/dumps/tb_gpio.vcd");
    $dumpvars(0, tb_gpio);

    // Init
    clk=0; resetn=0;
    psel=0; penable=0; pwrite=0; paddr=0; pwdata=0;
    gpio_drive=0; gpio_drive_en=32'h0;
    #40;
    resetn=1;

    // =========================================================
    // TEST 1: OUTPUT MODE — DUT drives all 32 pins
    // =========================================================
    $display("\n===== TEST 1: OUTPUT MODE =====");
    apb_write(32'h0000_20C0, 32'hFFFF_FFFF); // GDIR = all outputs
    apb_write(32'h0000_20C4, 32'hA5A5_A5A5); // GDAT = pattern
    #20;
    $display("gpio_pad (expect A5A5A5A5) = %h", gpio_pad);

    // =========================================================
    // TEST 2: INPUT MODE — TB drives all 32 pins, DUT reads back
    // =========================================================
    $display("\n===== TEST 2: INPUT MODE =====");
    apb_write(32'h0000_20C0, 32'h0000_0000); // GDIR = all inputs
    gpio_drive_en = 32'hFFFF_FFFF;
    gpio_drive    = 32'h3C3C_3C3C;
    #20;
    apb_read(32'h0000_20C4); // expect 3C3C3C3C

    // =========================================================
    // TEST 3: MIXED MODE — upper 16 output (DUT), lower 16 input (TB)
    // =========================================================
    $display("\n===== TEST 3: MIXED MODE =====");
    apb_write(32'h0000_20C0, 32'hFFFF_0000); // upper=output, lower=input
    gpio_drive_en = 32'h0000_FFFF;           // TB drives lower 16
    gpio_drive    = 32'h0000_5555;
    apb_write(32'h0000_20C4, 32'hAAAA_0000); // DUT drives upper 16
    #20;
    apb_read(32'h0000_20C4); // expect AAAA5555

    // =========================================================
    // TEST 4: GDIR readback
    // =========================================================
    $display("\n===== TEST 4: GDIR READBACK =====");
    apb_write(32'h0000_20C0, 32'hDEAD_BEEF); // write GDIR
    apb_read(32'h0000_20C0);                  // expect DEADBEEF

    // =========================================================
    // TEST 5: CONTENTION — DUT and TB both drive opposite values
    // =========================================================
    $display("\n===== TEST 5: CONTENTION =====");
    apb_write(32'h0000_20C0, 32'hFFFF_FFFF); // DUT drives all
    gpio_drive_en = 32'hFFFF_FFFF;
    gpio_drive    = 32'h0000_0000;            // TB drives opposite
    #20;
    $display("gpio_pad (expect X on contended bits) = %h", gpio_pad);

    // =========================================================
    // TEST 6: pslverr on bad address
    // =========================================================
    $display("\n===== TEST 6: PSLVERR ON BAD ADDR =====");
    gpio_drive_en = 32'h0;                    // release TB drive
    apb_write(32'h0000_20CC, 32'h1234_5678); // invalid address
    #20;
    $display("pslverr after bad write = %b (expect 1)", pslverr);

    #50;
    $display("\n===== ALL TESTS DONE =====");
    $finish;
end

endmodule
