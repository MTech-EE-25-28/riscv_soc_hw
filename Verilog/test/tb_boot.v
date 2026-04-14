`timescale 1ns/1ps
// ============================================================
//  tb_boot.v
//
//  Testbench for the RISC-V SoC bootloader.
//
//  Boot sequence:
//    1. Release SoC reset.
//    2. TB receives HANDSHAKE_BYTE (0xAA) from SoC TX.
//    3. TB sends ACK_BYTE (0x55) on RX.
//    4. TB streams all words from matrix_mul.hex over UART RX
//       (4 bytes per word, MSB first, as expected by boot_loader).
//    5. After IDLE_THRESHOLD idle cycles the bootloader asserts
//       cpu_resetn and the CPU starts executing.
//    6. TB monitors dmem writes and reports pass/fail.
//
//  UART parameters  (must match boot_loader defaults):
//    BRR = 27  →  baud_tick every 27 clocks
//    16 sub-ticks per bit  →  1 bit = 432 clocks  (8.64 µs at 50 MHz)
//    Frame: 1 start + 8 data (LSB-first) + 1 odd-parity + 1 stop
//    Frame duration: 11 × 432 = 4752 clocks  (~95 µs)
// ============================================================
module tb_boot;

// ----------------------------------------------------------------
// DUT signals
// ----------------------------------------------------------------
reg  clk, reset;
reg  pclk, presetn;
wire [31:0] PC, Result, ALUResult, DataAdr, WriteData_M, WriteData, ReadData;
wire        MemWrite, pwm_out0, pwm_out1;
wire [31:0] gpio_pad;
wire        tx;     // SoC → TB (bootloader handshake byte)
reg         rx;     // TB → SoC (ack + image bytes)
wire [3:0]  qspi_io;
wire        qspi_sck, qspi_cs_n, cpu_resetn;

soc dut (
    clk, reset, pclk, presetn,
    PC, Result, ALUResult, DataAdr, WriteData_M, WriteData, ReadData, MemWrite,
    pwm_out0, pwm_out1, gpio_pad, rx, tx, qspi_io, qspi_sck, qspi_cs_n, cpu_resetn
);

always #10 clk  = ~clk;
always #10 pclk = ~pclk;

// ----------------------------------------------------------------
// UART timing constants
//   BRR = 27  →  baud_tick period = 27 clocks
//   16 sub-ticks/bit  →  1 bit = 16 × 27 = 432 clocks
// ----------------------------------------------------------------
localparam integer BIT_CLKS = 432;   // clocks per UART bit

// Odd parity  (PS = 1):  parity_bit = 1 XOR (XOR of all data bits)
function [0:0] odd_parity;
    input [7:0] d;
    odd_parity = 1'b1 ^ (^d);
endfunction

// ----------------------------------------------------------------
// boot_mem: holds words loaded from hex
//   128 lines × 4 words/line = 512 words
// ----------------------------------------------------------------
reg [31:0] boot_mem  [0:2047];
localparam integer BOOT_WORDS = 120;
localparam string  BOOT_HEX_FILE = "./docker/bin/sum.hex";

// ----------------------------------------------------------------
// Parallel UART decoder for the SoC TX line.
// No parity (10-bit frame: 1 start + 8 data + 1 stop).
// Runs continuously in the background, independent of the main
// initial block so timing can never be missed.
// rx_byte_valid pulses high for exactly 1 clock when a byte is ready.
// ----------------------------------------------------------------
reg [7:0]  rx_decoded_byte;
reg        rx_byte_valid;

reg [9:0]  urx_timer;       // bit-period countdown (max = BIT_CLKS+BIT_CLKS/2 = 648)
reg [2:0]  urx_bit_cnt;     // 0-7
reg [7:0]  urx_shift;
reg [1:0]  urx_state;
reg        tx_d;            // delayed tx for falling-edge detection

localparam URX_IDLE = 2'd0, URX_DATA = 2'd1, URX_STOP = 2'd2;

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        urx_state       <= URX_IDLE;
        tx_d            <= 1'b1;
        rx_byte_valid   <= 1'b0;
        rx_decoded_byte <= 8'h0;
        urx_timer       <= 10'd0;
        urx_bit_cnt     <= 3'd0;
        urx_shift       <= 8'd0;
    end else begin
        tx_d          <= tx;
        rx_byte_valid <= 1'b0;    // default: no new byte
        case (urx_state)
            URX_IDLE: begin
                // Detect falling edge of tx → start bit
                if (tx_d && !tx) begin
                    // 1.5 bit-periods from falling edge → centre of bit 0
                    urx_timer   <= BIT_CLKS + BIT_CLKS/2 - 1;
                    urx_bit_cnt <= 3'd0;
                    urx_shift   <= 8'd0;
                    urx_state   <= URX_DATA;
                end
            end
            URX_DATA: begin
                if (urx_timer == 10'd0) begin
                    urx_shift[urx_bit_cnt] <= tx;
                    urx_timer              <= BIT_CLKS - 1;
                    if (urx_bit_cnt == 3'd7)
                        urx_state <= URX_STOP;
                    else
                        urx_bit_cnt <= urx_bit_cnt + 1;
                end else
                    urx_timer <= urx_timer - 1;
            end
            URX_STOP: begin
                if (urx_timer == 10'd0) begin
                    // Reached centre of stop bit – byte is complete
                    rx_decoded_byte <= urx_shift;
                    rx_byte_valid   <= 1'b1;
                    urx_state       <= URX_IDLE;
                end else
                    urx_timer <= urx_timer - 1;
            end
        endcase
    end
end

// ----------------------------------------------------------------
// send_uart_byte
//   Drives RX with one UART frame: start + 8 data (LSB-first) +
//   odd-parity + stop.
// ----------------------------------------------------------------
task send_uart_byte;
    input [7:0] data;
    integer     i;
    begin
        rx = 1'b0;                                // start bit
        repeat(BIT_CLKS) @(posedge clk);
        for (i = 0; i < 8; i = i + 1) begin      // 8 data bits, LSB first
            rx = data[i];
            repeat(BIT_CLKS) @(posedge clk);
        end
        // rx = odd_parity(data);                    // odd parity bit
        repeat(BIT_CLKS) @(posedge clk);
        rx = 1'b1;                                // stop bit
        repeat(BIT_CLKS) @(posedge clk);
    end
endtask

// ----------------------------------------------------------------
// Main boot sequence
// ----------------------------------------------------------------
integer w;

initial begin
    $dumpfile("./Verilog/dumps/tb_boot.vcd");
    $dumpvars(0, tb_boot);

    // Load hex image (512 words, 2048 bytes)
    $readmemh(BOOT_HEX_FILE, boot_mem);
    $display("[BOOT] Loading %0d words from %s", BOOT_WORDS, BOOT_HEX_FILE);

    // Initialise signals
    clk = 0; pclk = 0;
    reset = 0; presetn = 0;
    rx = 1'b1;          // UART idle high

    #100;
    reset = 1; presetn = 1;   // release system reset

    // -----------------------------------------------------------
    // Step 1 – receive HANDSHAKE_BYTE (0xAA) from bootloader TX
    // -----------------------------------------------------------
    $display("[BOOT] t=%0t  Waiting for handshake byte 0xAA from SoC...", $time);
    @(posedge rx_byte_valid);
    if (rx_decoded_byte === 8'hAA)
        $display("[BOOT] t=%0t  Received handshake 0x%02X  OK", $time, rx_decoded_byte);
    else
        $display("[BOOT] t=%0t  ERROR: expected 0xAA, received 0x%02X", $time, rx_decoded_byte);

    // -----------------------------------------------------------
    // Step 2 – send ACK_BYTE (0x55) to bootloader
    // -----------------------------------------------------------
    $display("[BOOT] t=%0t  Sending acknowledgement 0x55 to SoC...", $time);
    send_uart_byte(8'h55);
    $display("[BOOT] t=%0t  Ack sent.", $time);

    // -----------------------------------------------------------
    // Step 3 – stream hex file over UART, 4 bytes per word
    //          Bootloader expects MSB first:
    //            byte 0 → word[31:24]
    //            byte 1 → word[23:16]
    //            byte 2 → word[15:8]
    //            byte 3 → word[7:0]
    // -----------------------------------------------------------
    $display("[BOOT] t=%0t  Streaming %0d words from hex file...",
             $time, BOOT_WORDS);
    for (w = 0; w < BOOT_WORDS; w = w + 1) begin
        send_uart_byte(boot_mem[w][31:24]);
        send_uart_byte(boot_mem[w][23:16]);
        send_uart_byte(boot_mem[w][15:8]);
        send_uart_byte(boot_mem[w][7:0]);
        // Wait for 'X' ACK from bootloader confirming word was written to memory
        @(posedge rx_byte_valid);
        if (rx_decoded_byte !== 8'h58)
            $display("[BOOT] t=%0t  WARN: expected 'X' (0x58), got 0x%02X at word %0d",
                     $time, rx_decoded_byte, w);
    end
    $display("[BOOT] t=%0t  All %0d words sent and acknowledged.",
             $time, BOOT_WORDS * 4);

    // -----------------------------------------------------------
    // Step 4 – wait for bootloader idle-timeout then cpu_resetn
    //   IDLE_THRESHOLD = 300 polls × ~2 clocks/poll  ≈   600 clocks
    //   UART idle_flag asserts after 160 baud_ticks   = 4320 clocks
    //   2× headroom → 10 000 clocks = 200 µs
    // -----------------------------------------------------------
    #200_000;
    $display("[BOOT] t=%0t  Boot complete.  CPU should now be running.", $time);
end

// ----------------------------------------------------------------
// Step 5 – monitor CPU dmem writes for pass / fail
//   Matches tb_soc_mm.v convention:
//     0x0000_1004  matrix result values
//     0x0000_1008  halt flag  (== 1  →  PASS)
// ----------------------------------------------------------------
integer skip_1 = 0, skip_2 = 0;

always @(negedge clk) begin
    if (MemWrite && reset) begin
        if (DataAdr == 32'h0000_1004) begin
            // skip_1 = skip_1 + 1;
            // if (skip_1 > 1)
                $display("[CPU]  t=%0t result @ 0x1004 = %0d  (0x%08X)",
                         $time, $signed(WriteData_M), WriteData_M);
        end
        if (DataAdr == 32'h0000_1008) begin
            // skip_2 = skip_2 + 1;
            // if (skip_2 > 1) begin
                if (WriteData_M == 32'd1)
                    $display("[CPU]  t=%0t  PASS: program halted correctly (halt_flag = 1)",
                             $time);
                else
                    $display("[CPU]  t=%0t  FAIL: unexpected halt value = %0d",
                             $time, WriteData_M);
                #100;
                $finish;
            // end
        end
    end
end

// ----------------------------------------------------------------
// Global watchdog  (500 ms gives ~200 ms boot + plenty of runtime)
// ----------------------------------------------------------------
initial begin
    #500_000_000;
    $display("[TIMEOUT] t=%0t  Simulation exceeded 500 ms budget.", $time);
    $finish;
end

endmodule