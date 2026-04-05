`timescale 1ns / 1ps
// Testbench for APB_UART_Wrapper (matching tb_timer.v style)
// Address map (BASE = 0x0000_2040):
//   SR   BASE+0x00 = 0x2040  (read)  [7:0] = {ne,fe,pe,owe,idle,tc,rxne,txe}
//   RDR  BASE+0x04 = 0x2044  (read)  [8:0] received data
//   TDR  BASE+0x08 = 0x2048  (write) [8:0] transmit data
//   CR   BASE+0x0C = 0x204C  (write) [7:0] {IERXNE,IETXE,PS,PCE,M,RE,TE,UE}
//   BRR  BASE+0x10 = 0x2050  (write) [15:0] baud divisor (baud_tick every BRR cycles)
// pready = 1 always (zero-wait-state)
// Loopback: tx wired back to rx for self-test

module tb_uart;

localparam BASE     = 32'h0000_2040;
localparam SR_ADDR  = BASE + 32'h00;  // 0x2040
localparam RDR_ADDR = BASE + 32'h04;  // 0x2044
localparam TDR_ADDR = BASE + 32'h08;  // 0x2048
localparam CR_ADDR  = BASE + 32'h0C;  // 0x204C
localparam BRR_ADDR = BASE + 32'h10;  // 0x2050

// SR bit indices
localparam TC   = 2; // transmission complete
localparam RXNE = 1; // RX not empty
localparam TXE  = 0; // TX buffer empty

reg         clk, resetn;
reg         psel, penable, pwrite;
reg  [31:0] paddr, pwdata;
wire [31:0] prdata;
wire        pready, pslverr;
wire        tx;

// Loopback: connect TX back to RX
uart_top dut (
    .pclk(clk),       .presetn(resetn),
    .psel(psel),      .penable(penable), .pwrite(pwrite),
    .paddr(paddr),    .pwdata(pwdata),
    .prdata(prdata),  .pready(pready),   .pslverr(pslverr),
    .rx(tx),          // loopback
    .tx(tx)
);

always #10 clk = ~clk; // 50 MHz

// ---- APB tasks (matching tb_timer.v style) ----

task apb_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge clk); #1;
        psel=1; pwrite=1; penable=0; paddr=addr; pwdata=data;
        @(posedge clk); #1;
        penable=1;
        @(posedge clk); #1;    // pready=1 always, completes here
        psel=0; penable=0; pwrite=0;
    end
endtask

// apb_rdata captures prdata before penable drops (combinational output)
reg [31:0] apb_rdata;

task apb_read(input [31:0] addr);
    begin
        @(posedge clk); #1;
        psel=1; pwrite=0; penable=0; paddr=addr;
        @(posedge clk); #1;
        penable=1;
        @(posedge clk);
        apb_rdata = prdata;   // capture while penable still high
        $display("APB READ [%h] = %h", addr, apb_rdata); #1;
        psel=0; penable=0;
    end
endtask

// Poll SR until a given bit is set; result left in apb_rdata
task wait_sr_bit(input integer bit_idx);
    integer timeout;
    begin
        apb_rdata = 32'd0;
        timeout   = 0;
        while (!apb_rdata[bit_idx] && timeout < 20000) begin
            @(posedge clk); #1;
            psel=1; pwrite=0; penable=0; paddr=SR_ADDR;
            @(posedge clk); #1;
            penable=1;
            @(posedge clk);
            apb_rdata = prdata;  // capture before deassert
            #1;
            psel=0; penable=0;
            timeout = timeout + 1;
        end
        if (timeout >= 20000)
            $display("TIMEOUT waiting for SR[%0d]", bit_idx);
    end
endtask

// ---- Test sequence ----

initial begin
    $dumpfile("./Verilog/dumps/tb_uart.vcd");
    $dumpvars(0, tb_uart);

    // Init
    clk=0; resetn=0; apb_rdata=0;
    psel=0; penable=0; pwrite=0; paddr=0; pwdata=0;
    #40;
    resetn=1;

    // Configure UART: BRR=4 (fast sim), CR=0x07 (UE+TE+RE)
    apb_write(BRR_ADDR, 32'h0000_0004);
    apb_write(CR_ADDR,  32'h0000_0007); // UE=1, TE=1, RE=1

    // =========================================================
    // TEST 1: Verify TXE=1 after enable (TX buffer empty)
    // =========================================================
    $display("\n===== TEST 1: SR AFTER ENABLE (expect TXE=1) =====");
    apb_read(SR_ADDR);
    $display("SR = %08b  TXE=%b TC=%b RXNE=%b",
             apb_rdata[7:0], apb_rdata[TXE], apb_rdata[TC], apb_rdata[RXNE]);

    // =========================================================
    // TEST 2: TX a byte — write TDR, wait for TC
    // =========================================================
    $display("\n===== TEST 2: TX BYTE 0x55, WAIT TC =====");
    apb_write(TDR_ADDR, 32'h0000_0055);
    wait_sr_bit(TC);
    $display("SR after TC = %08b  TC=%b (expect 1)", apb_rdata[7:0], apb_rdata[TC]);

    // =========================================================
    // TEST 3: Loopback — TX 0xA5, wait RXNE, read RDR
    // =========================================================
    $display("\n===== TEST 3: LOOPBACK TX=0xA5, READ RDR =====");
    apb_write(TDR_ADDR, 32'h0000_00A5);
    wait_sr_bit(RXNE);
    $display("SR with RXNE = %08b  RXNE=%b (expect 1)", apb_rdata[7:0], apb_rdata[RXNE]);
    apb_read(RDR_ADDR); // expect lower 8 bits = 0xA5

    // =========================================================
    // TEST 4: pslverr on invalid write address
    // =========================================================
    $display("\n===== TEST 4: PSLVERR ON INVALID WRITE ADDR =====");
    @(posedge clk); #1;
    psel=1; pwrite=1; penable=0; paddr=BASE+32'h14; pwdata=32'hDEAD;
    @(posedge clk); #1;
    penable=1;
    @(posedge clk);
    $display("pslverr during access = %b (expect 1)", pslverr); #1;
    psel=0; penable=0; pwrite=0;

    #100;
    $display("\n===== ALL TESTS DONE =====");
    $finish;
end

endmodule
