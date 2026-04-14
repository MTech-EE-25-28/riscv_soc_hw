`timescale 1ns / 1ps
// ============================================================
//  boot_loader.v
//
//  Bootloader for boot_uart / uart_top.
//
//  Key differences vs. original boot_uart:
//  ----------------------------------------
//  1. SR  register is at APB offset 0x00  (returns {24'd0, SR[7:0]})
//     RDR register is at APB offset 0x04  (returns {23'd0, RDR[8:0]})
//
//  2. Receive flow in UART_receive state:
//       a. Default: issue APB READ to SR_addr (0x00).
//       b. When p_r_data[1] (RXNE) is seen, set 'reading_rdr' flag.
//          Next cycle: issue APB READ to RDR_addr (0x04).
//       c. The cycle after that p_r_data holds the fresh RDR byte.
//          Latch p_r_data[7:0] into the correct slice of out_send_data
//          and clear 'reading_rdr'.
//       d. After the 4th byte (counter==2'b11) set mem_send_fully_loaded
//          for exactly one cycle  ->  write_data_en pulses high while
//          out_send_data holds the complete, correct 32-bit word.
//
//  3. write_data_en  is a combinational wire (= mem_send_fully_loaded).
//     out_send_data  contains partial data between pulses; it is only
//     guaranteed correct when write_data_en is 1.
//
//  4. UART_baud_rate default changed to 27.
//     Idle threshold raised to 300 clock cycles:
//       1 UART frame at BRR=27  =  11 bits x 27 clocks  = 297 clocks.
//     counter_2 widened to 9 bits to accommodate the larger threshold.
//
//  5. p_write stays 0 throughout UART_receive; the memory controller
//     uses the dedicated out_send_data / write_data_en pair instead.
//
//  6. Handshake sequence (NEW):
//     After BRR and CR are configured, the bootloader:
//       a. Sends HANDSHAKE_BYTE over TX (UART_send_byte state).
//          CR is now written with TE=1 as well as RE=1 so the transmitter
//          is enabled.  CR byte = {2'b00, PS, PCE, M=0, RE=1, TE=1, UE=1}
//          = 0x37 with default parity settings.
//       b. Polls SR[2] (TC - Transmission Complete) until the frame is
//          fully shifted out (UART_poll_tc state).
//       c. Waits for the sender to echo/ack one byte back
//          (UART_recv_ack state), using the same two-phase reading_rdr
//          mechanism as UART_receive.
//       d. Latches the ack byte; checks it against ACK_BYTE and stores
//          the result in ack_ok.  Regardless of ack_ok, the FSM advances
//          to UART_receive so that a wrong ack does not hang the system.
//          ack_ok can be monitored externally for debug/error reporting.
// ============================================================

module boot_loader #(
    parameter UART_BASE_ADDR  = 32'h0000_2040,
    parameter UART_baud_rate  = 32'd27,         // BRR=27 for correct baud
    parameter UART_parity_sel = 1'b1,           // 0=even, 1=odd  -> CR[5]
    parameter UART_parity_en  = 1'b1,           // parity enable  -> CR[4]
    parameter HANDSHAKE_BYTE  = 8'hAA,          // byte sent to signal sender to start
    parameter ACK_BYTE        = 8'h55           // expected ack byte from sender
)(
    input         clk,
    input         uart_select,   // activate UART path when high
    output reg    reset_cpu,     // CPU reset; active-low during boot, high when done
    input         main_reset,    // MCU-wide reset, active-low

    // APB master interface (connects to uart_top)
    input      [31:0] p_r_data,  // prdata from uart_top
    output reg [31:0] p_addr,    // APB address
    output reg [31:0] p_w_data,  // APB write data
    output reg        psel,
    output reg        penable,
    input             pready,    // ignored (uart_top always-ready)
    output reg        p_write,
    input             pslverr,   // ignored
    output reg        presetn,   // APB reset to uart_top (active-low)

    // Word-ready interface to memory controller
    output reg [31:0] out_send_data,  // packed 32-bit instruction word
    output            write_data_en  // 1-cycle pulse when out_send_data is valid

    // Handshake status (informational; 1 = received ack matched ACK_BYTE)
    //output reg        ack_ok
);

    // ----------------------------------------------------------
    //  State encoding
    // ----------------------------------------------------------
    localparam IDLE             = 4'b0000;
    localparam UART_BRR_set     = 4'b1001;
    localparam UART_control_reg = 4'b1010;
    localparam UART_send_byte   = 4'b1100;  // NEW: write HANDSHAKE_BYTE to TDR
    localparam UART_poll_tc     = 4'b1101;  // NEW: poll SR[2] (TC) until TX done
    localparam UART_recv_ack    = 4'b1110;  // NEW: receive and verify ack byte
    localparam UART_receive     = 4'b1011;
    localparam finished         = 4'b1111;

    // ----------------------------------------------------------
    //  APB address offsets (relative to UART_BASE_ADDR)
    // ----------------------------------------------------------
    localparam SR_addr          = 8'h00; // {24'd0, SR[7:0]}         read-only
    localparam RDR_addr         = 8'h04; // {23'd0, RDR[8:0]}        read-only
    localparam transfer_addr    = 8'h08; // TDR - written for handshake TX
    localparam control_reg_addr = 8'h0c; // CR  - written once
    localparam baud_rate_addr   = 8'h10; // BRR - written once

    // ----------------------------------------------------------
    //  SR bit positions (from UART_module SR_out assignment):
    //    SR[7] = ne_flag   SR[6] = fe_flag  SR[5] = pe_flag
    //    SR[4] = owe_flag  SR[3] = idle_flag (RXIDLE)
    //    SR[2] = tc_flag   SR[1] = rxne_flag SR[0] = txe_flag
    // ----------------------------------------------------------

    // ----------------------------------------------------------
    //  Idle threshold
    //  At BRR=27: 1 bit = 27 clocks, 1 frame (11 bits) = 297 clocks.
    //  Wait 300 consecutive SR-idle cycles before declaring done.
    // ----------------------------------------------------------
    localparam [8:0] IDLE_THRESHOLD = 9'd300;

    // ----------------------------------------------------------
    //  Registers
    // ----------------------------------------------------------
    reg [3:0] curr_state, next_state;

    reg        mem_send_fully_loaded; // 1-cycle flag after 4th byte latched
    reg [1:0]  counter;               // byte counter within a 32-bit word (0-3)
    reg [8:0]  counter_2;             // idle-cycle counter (widened for BRR=27)
    reg        reading_rdr;           // 1 = current cycle address is RDR_addr
                                      //   (shared by UART_recv_ack & UART_receive)

    // Handshake ack registers
    reg [7:0]  ack_recv;              // latched ack byte from sender
    reg        ack_received;          // set for one cycle when ack RDR is read
    
    reg        ack_ok;
    // ----------------------------------------------------------
    //  write_data_en : combinational pulse tied to the flag
    // ----------------------------------------------------------
    assign write_data_en = mem_send_fully_loaded;

    // ----------------------------------------------------------
    //  Next-state logic (combinational)
    // ----------------------------------------------------------
    //
    //  UART_poll_tc  : p_r_data[2] = SR[2] = TC (Transmission Complete).
    //                  Wait until TC is asserted before expecting an ack.
    //
    //  UART_recv_ack : ack_received is set (for one cycle) in the
    //                  sequential block when Phase B completes.
    //
    //  UART_receive  : Idle detection only valid when reading SR
    //                  (~reading_rdr). SR[3] = RXIDLE; counter_2 must
    //                  reach IDLE_THRESHOLD before transitioning to done.
    // ----------------------------------------------------------
    always @(*) begin
        case (curr_state)
            IDLE             : next_state = uart_select ? UART_BRR_set : IDLE;
            UART_BRR_set     : next_state = UART_control_reg;
            UART_control_reg : next_state = UART_send_byte;      // -> handshake TX

            // Send HANDSHAKE_BYTE: one-cycle APB write to TDR then move on
            UART_send_byte   : next_state = UART_poll_tc;

            // Stay here until TC (SR[2]) goes high -> TX frame fully sent
            UART_poll_tc     : next_state = p_r_data[2] ? UART_recv_ack
                                                         : UART_poll_tc;

            // Wait until Phase B completes and ack_received pulses high
            UART_recv_ack    : next_state = ack_received ? UART_receive
                                                         : UART_recv_ack;

            UART_receive     : next_state =
                                  (!reading_rdr &&
                                   p_r_data[3]  &&
                                   counter_2 >= IDLE_THRESHOLD)
                                  ? finished : UART_receive;

            finished         : next_state = (~main_reset) ? IDLE : finished;
            default          : next_state = IDLE;
        endcase
    end

    // ----------------------------------------------------------
    //  Sequential logic
    // ----------------------------------------------------------
    always @(posedge clk or negedge main_reset) begin
        if (~main_reset) begin
            reset_cpu             <= 1'b0;   // hold CPU in reset (active-low)
            presetn               <= 1'b0;   // assert APB reset to uart_top
            curr_state            <= IDLE;
            counter               <= 2'b00;
            counter_2             <= 9'd0;
            mem_send_fully_loaded <= 1'b0;
            reading_rdr           <= 1'b0;
            ack_recv              <= 8'h00;
            ack_received          <= 1'b0;
            ack_ok                <= 1'b0;
            p_write               <= 1'b0;
            penable               <= 1'b0;
            psel                  <= 1'b0;
            p_w_data              <= 32'd0;
            p_addr                <= 32'hFFFF_FFFF;
            out_send_data         <= 32'd0;
        end
        else begin
            curr_state <= next_state;

            case (curr_state)

                // --------------------------------------------------
                //  IDLE - release APB reset, quiesce bus
                // --------------------------------------------------
                IDLE : begin
                    presetn               <= 1'b1;
                    p_write               <= 1'b0;
                    penable               <= 1'b0;
                    psel                  <= 1'b0;
                    p_w_data              <= 32'd0;
                    p_addr                <= 32'hFFFF_FFFF;
                    counter               <= 2'b00;
                    counter_2             <= 9'd0;
                    mem_send_fully_loaded <= 1'b0;
                    reading_rdr           <= 1'b0;
                    ack_recv              <= 8'h00;
                    ack_received          <= 1'b0;
                    ack_ok                <= 1'b0;
                    out_send_data         <= 32'd0;
                end

                // --------------------------------------------------
                //  UART_BRR_set - write baud-rate register (BRR)
                //  APB WRITE  p_addr = BASE + 0x10
                //             p_w_data = UART_baud_rate (=27 default)
                // --------------------------------------------------
                UART_BRR_set : begin
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    p_w_data <= UART_baud_rate;
                    p_addr   <= UART_BASE_ADDR + baud_rate_addr;
                end

                // --------------------------------------------------
                //  UART_control_reg - write control register (CR)
                //  APB WRITE  p_addr = BASE + 0x0C
                //
                //  p_w_data[7:0]:
                //    [7:6] = 2'b00          interrupts disabled
                //    [5]   = UART_parity_sel PS  (0=even, 1=odd)
                //    [4]   = UART_parity_en  PCE (parity control enable)
                //    [3]   = 1'b0            M   (8-bit word length)
                //    [2]   = 1'b1            RE  (receiver enable)
                //    [1]   = 1'b1            TE  (transmitter enable) <-- CHANGED
                //    [0]   = 1'b1            UE  (UART enable)
                //
                //  TE must be 1 so the UART can send the handshake byte.
                //  With PS=1, PCE=1 => 8'b0011_0111 = 0x37
                // --------------------------------------------------
                UART_control_reg : begin
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    p_w_data <= {24'h00_0000,
                                 2'b00,
                                 UART_parity_sel,
                                 UART_parity_en,
                                 4'b0111};   // M=0, RE=1, TE=1, UE=1
                    p_addr   <= UART_BASE_ADDR + control_reg_addr;
                end

                // --------------------------------------------------
                //  UART_send_byte (NEW)
                //
                //  Issue one APB WRITE to TDR with HANDSHAKE_BYTE.
                //  This tells the sender on the other end to begin
                //  its data transfer.
                //
                //  TDR offset = 0x08.  TDR is 9-bit; MSB = 0 for
                //  8-bit word mode (M=0).
                //  p_w_data = {23'd0, 1'b0, HANDSHAKE_BYTE}
                // --------------------------------------------------
                UART_send_byte : begin
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    p_w_data <= {23'd0, 1'b0, HANDSHAKE_BYTE};
                    p_addr   <= UART_BASE_ADDR + transfer_addr;
                    // Next state: UART_poll_tc (next_state already set combinationally)
                end

                // --------------------------------------------------
                //  UART_poll_tc (NEW)
                //
                //  Poll SR continuously; wait until TC (SR[2]) = 1,
                //  indicating the HANDSHAKE_BYTE frame has been fully
                //  shifted out onto the TX line.
                //
                //  p_r_data holds SR from the PREVIOUS cycle's read,
                //  so the first SR sample arrives on the cycle after
                //  entering this state.  TC will only assert after many
                //  baud-clock cycles, so the one-cycle pipeline delay
                //  is inconsequential.
                //
                //  p_write = 0 (read-only).
                //  p_addr  = SR_addr held constant throughout.
                // --------------------------------------------------
                UART_poll_tc : begin
                    p_write <= 1'b0;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    p_addr  <= UART_BASE_ADDR + SR_addr;
                    // next_state transitions to UART_recv_ack when
                    // p_r_data[2] (TC) is seen by the combinational block.
                end

                // --------------------------------------------------
                //  UART_recv_ack (NEW)
                //
                //  Wait for the remote sender to echo back one ack byte.
                //  Uses the same two-phase (reading_rdr) mechanism as
                //  UART_receive.
                //
                //  Phase A (reading_rdr == 0):
                //    Read SR at 0x00.  If RXNE (SR[1]) is asserted,
                //    switch to Phase B.
                //
                //  Phase B (reading_rdr == 1):
                //    Read RDR at 0x04.  Latch p_r_data[7:0] into
                //    ack_recv, compare with ACK_BYTE, set ack_ok.
                //    Pulse ack_received high for one cycle so that
                //    next_state (combinational) advances to UART_receive.
                //
                //  After ack_received pulses, clear it so subsequent
                //  re-entries to this state (after a main_reset) start
                //  fresh.
                // --------------------------------------------------
                UART_recv_ack : begin
                    p_write      <= 1'b0;
                    penable      <= 1'b1;
                    psel         <= 1'b1;
                    ack_received <= 1'b0; // clear unless Phase B completes below

                    if (reading_rdr) begin
                        // -----------------------------------------------
                        //  Phase B: p_r_data now holds the fresh RDR byte
                        // -----------------------------------------------
                        reading_rdr  <= 1'b0;

                        // Latch ack and verify
                        ack_recv     <= p_r_data[7:0];
                        ack_ok       <= (p_r_data[7:0] == ACK_BYTE);

                        // Pulse ack_received so next_state sees UART_receive
                        ack_received <= 1'b1;

                        // Return address to SR for UART_receive's first cycle
                        p_addr <= UART_BASE_ADDR + SR_addr;
                    end
                    else begin
                        // -----------------------------------------------
                        //  Phase A: read SR this cycle
                        //  p_r_data holds last cycle's SR result
                        // -----------------------------------------------
                        if (p_r_data[1]) begin  // SR[1] = RXNE: ack byte ready
                            reading_rdr <= 1'b1;
                            p_addr      <= UART_BASE_ADDR + RDR_addr; // Phase B
                        end
                        else begin
                            p_addr <= UART_BASE_ADDR + SR_addr; // keep polling SR
                        end
                    end
                end // UART_recv_ack

                // --------------------------------------------------
                //  UART_receive - poll for bytes, pack into 32-bit words
                //
                //  Two-phase APB-read cycle per byte:
                //
                //  Phase A (reading_rdr == 0)  :  read SR at 0x00
                //    p_r_data = {24'd0, SR[7:0]}
                //    SR[1] = RXNE  - new byte in RDR
                //    SR[3] = RXIDLE - RX line idle (no activity)
                //
                //    -> If RXNE=1: set reading_rdr, next cycle read RDR
                //    -> Accumulate idle counter on SR[3]; reset on activity
                //    -> Clear mem_send_fully_loaded (was high only last cycle)
                //
                //  Phase B (reading_rdr == 1)  :  read RDR at 0x04
                //    p_r_data = {23'd0, RDR[8:0]}
                //    p_r_data[7:0] = received byte (8-bit mode)
                //
                //    -> Latch into out_send_data slice based on counter
                //    -> After 4th byte: set mem_send_fully_loaded (one cycle)
                //       write_data_en pulses high; out_send_data is complete
                //    -> Clear reading_rdr; return to Phase A (SR read)
                //
                //  p_write stays 0 throughout; memory controller uses
                //  out_send_data / write_data_en directly.
                // --------------------------------------------------
                UART_receive : begin
                    p_write <= 1'b0;  // bootloader never writes in receive phase
                    penable <= 1'b1;
                    psel    <= 1'b1;

                    if (reading_rdr) begin
                        // -----------------------------------------------
                        //  Phase B: p_r_data now holds the fresh RDR byte
                        // -----------------------------------------------
                        reading_rdr <= 1'b0;
                        counter_2   <= 9'd0; // activity detected - reset idle ctr

                        // Latch byte into the correct word slice
                        case (counter)
                            2'b00 : begin
                                out_send_data[31:24] <= p_r_data[7:0];
                                counter              <= 2'b01;
                                mem_send_fully_loaded <= 1'b0;
                            end

                            2'b01 : begin
                                out_send_data[23:16] <= p_r_data[7:0];
                                counter              <= 2'b10;
                            end

                            2'b10 : begin
                                out_send_data[15:8]  <= p_r_data[7:0];
                                counter              <= 2'b11;
                            end

                            2'b11 : begin
                                // 4th byte: complete the word and pulse write_data_en
                                out_send_data[7:0]    <= p_r_data[7:0];
                                mem_send_fully_loaded <= 1'b1; // write_data_en goes HIGH
                                counter               <= 2'b00; // reset for next word
                            end
                        endcase

                        // Return to SR read next cycle
                        p_addr <= UART_BASE_ADDR + SR_addr;
                    end
                    else begin
                        // -----------------------------------------------
                        //  Phase A: read SR this cycle
                        //  p_r_data holds last cycle's SR result
                        // -----------------------------------------------

                        // Clear the one-cycle write_data_en pulse
                        mem_send_fully_loaded <= 1'b0;

                        // Idle counter: increment while RX line is idle
                        if (p_r_data[3])       // SR[3] = RXIDLE
                            counter_2 <= counter_2 + 1;
                        else
                            counter_2 <= 9'd0;

                        // RXNE check: if new byte ready, switch to RDR read
                        if (p_r_data[1]) begin // SR[1] = RXNE
                            reading_rdr <= 1'b1;
                            p_addr      <= UART_BASE_ADDR + RDR_addr; // Phase B address
                        end
                        else begin
                            p_addr <= UART_BASE_ADDR + SR_addr; // stay on SR
                        end
                    end
                end // UART_receive

                // --------------------------------------------------
                //  finished - release CPU from reset
                // --------------------------------------------------
                finished : begin
                    reset_cpu <= 1'b1; // de-assert CPU reset (active-low design)
                end

            endcase
        end
    end

endmodule

/*`timescale 1ns / 1ps
// ============================================================
//  boot_loader.v
//
//  Complete state sequence
//  -----------------------
//  IDLE
//    -> UART_BRR_set      write BRR (baud rate)
//    -> UART_control_reg  write CR  (UE | TE | RE | PCE | PS)
//    -> UART_send_byte    APB write HANDSHAKE_BYTE to TDR
//    -> UART_poll_tc      poll SR[2] (TC) until handshake frame is out
//    -> UART_recv_ack     two-phase read: wait RXNE then read RDR ack byte
//    -> UART_receive      pack bytes into 32-bit words;
//                         store each completed word in internal rx_mem[];
//                         exit after IDLE_THRESHOLD consecutive idle SR polls
//    -> UART_tx_start     initialise TX pointers, load first word
//    -> UART_tx_load      APB write current byte to TDR
//    -> UART_tx_wait      poll SR[2] (TC); advance byte/word counters;
//                         loop to UART_tx_load or exit to finished
//    -> finished          de-assert CPU reset
//
//  SR bit map  (UART_module SR_out = {NE,FE,PE,OWE,IDLE,TC,RXNE,TXE}):
//    [7]=NE  [6]=FE  [5]=PE  [4]=OWE
//    [3]=IDLE(RXIDLE)  [2]=TC  [1]=RXNE  [0]=TXE
//
//  APB offsets from UART_BASE_ADDR:
//    0x00 SR  (read)   0x04 RDR (read)
//    0x08 TDR (write)  0x0C CR  (write)   0x10 BRR (write)
//
//  Internal storage
//  ----------------
//  rx_mem[0..MEM_DEPTH-1] holds 32-bit words received over UART.
//  Words are committed during UART_receive Phase A, the cycle after
//  the 4th byte is latched (out_send_data is fully valid at that point).
//  mem_write_ptr counts words stored; 8-bit ? max 256 entries.
//
//  TX-back
//  -------
//  After reception the bootloader re-sends every stored word byte-by-byte,
//  MSB first, polling TC between bytes.  Writing TDR also clears TC inside
//  the UART, so there is no risk of a stale TC=1 from the handshake phase.
// ============================================================

module boot_loader #(
    parameter UART_BASE_ADDR  = 32'h0000_2040,
    parameter UART_baud_rate  = 32'd27,
    parameter UART_parity_sel = 1'b1,   // CR[5] PS  : 0=even, 1=odd
    parameter UART_parity_en  = 1'b1,   // CR[4] PCE
    parameter HANDSHAKE_BYTE  = 8'hAA,  // sent to trigger sender
    parameter ACK_BYTE        = 8'h55,  // expected ack (stored internally)
    parameter MEM_DEPTH       = 256     // # of 32-bit words; ptr is 8-bit (max 256)
)(
    input         clk,
    input         uart_select,
    output reg    reset_cpu,    // held low during boot; released high when done
    input         main_reset,   // MCU-wide async reset, active-low

    // APB master
    input      [31:0] p_r_data,
    output reg [31:0] p_addr,
    output reg [31:0] p_w_data,
    output reg        psel,
    output reg        penable,
    input             pready,   // ignored (uart_top always-ready)
    output reg        p_write,
    input             pslverr,  // ignored
    output reg        presetn,  // APB reset to uart_top (active-low)

    // Word-ready interface to memory controller
    output reg [31:0] out_send_data,  // valid when write_data_en=1
    output            write_data_en   // 1-cycle pulse
);

    // ----------------------------------------------------------
    //  State encoding
    // ----------------------------------------------------------
    localparam IDLE             = 4'b0000;
    localparam UART_tx_start    = 4'b0001;  // init TX pointers, load first word
    localparam UART_tx_load     = 4'b0010;  // write byte to TDR
    localparam UART_tx_wait     = 4'b0011;  // poll TC; advance counters
    localparam UART_BRR_set     = 4'b1001;
    localparam UART_control_reg = 4'b1010;
    localparam UART_receive     = 4'b1011;
    localparam UART_send_byte   = 4'b1100;  // write HANDSHAKE_BYTE
    localparam UART_poll_tc     = 4'b1101;  // wait TC after handshake TX
    localparam UART_recv_ack    = 4'b1110;  // receive ack byte
    localparam finished         = 4'b1111;

    // ----------------------------------------------------------
    //  APB address offsets
    // ----------------------------------------------------------
    localparam SR_addr          = 8'h00;
    localparam RDR_addr         = 8'h04;
    localparam transfer_addr    = 8'h08;
    localparam control_reg_addr = 8'h0c;
    localparam baud_rate_addr   = 8'h10;

    // Idle threshold: 300 SR polls ? 1 full frame at BRR=27 (297 clocks)
    localparam [8:0] IDLE_THRESHOLD = 9'd300;

    // ----------------------------------------------------------
    //  State
    // ----------------------------------------------------------
    reg [3:0] curr_state, next_state;

    // ----------------------------------------------------------
    //  Receive-path registers
    // ----------------------------------------------------------
    reg        mem_send_fully_loaded;
    reg [1:0]  counter;      // byte index within current word (0-3)
    reg [8:0]  counter_2;    // idle SR-poll counter
    reg        reading_rdr;  // shared two-phase flag

    // Ack (internal only - no external port)
    reg [7:0]  ack_recv;
    reg        ack_received; // 1-cycle pulse

    // ----------------------------------------------------------
    //  Internal receive storage
    // ----------------------------------------------------------
    reg [31:0] rx_mem [0:MEM_DEPTH-1];
    reg [7:0]  mem_write_ptr;  // words stored so far

    // ----------------------------------------------------------
    //  TX-back registers
    // ----------------------------------------------------------
    reg [31:0] tx_word;
    reg [7:0]  mem_read_ptr;   // index of NEXT word to load
    reg [1:0]  tx_byte_sel;    // 0=MSB … 3=LSB

    // ----------------------------------------------------------
    //  write_data_en
    // ----------------------------------------------------------
    assign write_data_en = mem_send_fully_loaded;

    // ----------------------------------------------------------
    //  Next-state (combinational)
    // ----------------------------------------------------------
    always @(*) begin
        case (curr_state)
            IDLE             : next_state = uart_select ? UART_BRR_set : IDLE;
            UART_BRR_set     : next_state = UART_control_reg;
            UART_control_reg : next_state = UART_send_byte;

            // Handshake TX
            UART_send_byte   : next_state = UART_poll_tc;
            UART_poll_tc     : next_state = p_r_data[2] ? UART_recv_ack   // TC=SR[2]
                                                         : UART_poll_tc;
            UART_recv_ack    : next_state = ack_received ? UART_receive
                                                         : UART_recv_ack;

            // Receive loop - exit on idle
            UART_receive     : next_state =
                                  (!reading_rdr &&
                                   p_r_data[3]  &&          // SR[3] = RXIDLE
                                   counter_2 >= IDLE_THRESHOLD)
                                  ? UART_tx_start : UART_receive;

            // TX-back chain
            UART_tx_start    : next_state = (mem_write_ptr == 8'd0) ? finished
                                                                      : UART_tx_load;
            UART_tx_load     : next_state = UART_tx_wait;

            // next_state uses PRE-increment values of tx_byte_sel / mem_read_ptr.
            // The sequential block updates them on the same rising edge,
            // so the transition is decided on current (pre-update) values.
            UART_tx_wait     : next_state =
                                  p_r_data[2]
                                  ? ((tx_byte_sel == 2'b11 &&
                                      mem_read_ptr >= mem_write_ptr)
                                     ? finished : UART_tx_load)
                                  : UART_tx_wait;

            finished         : next_state = (~main_reset) ? IDLE : finished;
            default          : next_state = IDLE;
        endcase
    end

    // ----------------------------------------------------------
    //  Sequential
    // ----------------------------------------------------------
    always @(posedge clk or negedge main_reset) begin
        if (~main_reset) begin
            reset_cpu             <= 1'b0;
            presetn               <= 1'b0;
            curr_state            <= IDLE;
            counter               <= 2'b00;
            counter_2             <= 9'd0;
            mem_send_fully_loaded <= 1'b0;
            reading_rdr           <= 1'b0;
            ack_recv              <= 8'h00;
            ack_received          <= 1'b0;
            mem_write_ptr         <= 8'd0;
            mem_read_ptr          <= 8'd0;
            tx_word               <= 32'd0;
            tx_byte_sel           <= 2'b00;
            p_write               <= 1'b0;
            penable               <= 1'b0;
            psel                  <= 1'b0;
            p_w_data              <= 32'd0;
            p_addr                <= 32'hFFFF_FFFF;
            out_send_data         <= 32'd0;
        end
        else begin
            curr_state <= next_state;

            case (curr_state)

                // ------------------------------------------------
                //  IDLE
                // ------------------------------------------------
                IDLE : begin
                    presetn               <= 1'b1;
                    p_write               <= 1'b0;
                    penable               <= 1'b0;
                    psel                  <= 1'b0;
                    p_w_data              <= 32'd0;
                    p_addr                <= 32'hFFFF_FFFF;
                    counter               <= 2'b00;
                    counter_2             <= 9'd0;
                    mem_send_fully_loaded <= 1'b0;
                    reading_rdr           <= 1'b0;
                    ack_recv              <= 8'h00;
                    ack_received          <= 1'b0;
                    mem_write_ptr         <= 8'd0;
                    mem_read_ptr          <= 8'd0;
                    tx_word               <= 32'd0;
                    tx_byte_sel           <= 2'b00;
                    out_send_data         <= 32'd0;
                end

                // ------------------------------------------------
                //  UART_BRR_set  - write BRR (offset 0x10)
                // ------------------------------------------------
                UART_BRR_set : begin
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    p_w_data <= UART_baud_rate;
                    p_addr   <= UART_BASE_ADDR + baud_rate_addr;
                end

                // ------------------------------------------------
                //  UART_control_reg  - write CR (offset 0x0C)
                //
                //  CR[7:6]=00  no interrupts
                //  CR[5]   = UART_parity_sel  (PS)
                //  CR[4]   = UART_parity_en   (PCE)
                //  CR[3]   = 0  (M, 8-bit word)
                //  CR[2]   = 1  RE  receiver enable
                //  CR[1]   = 1  TE  transmitter enable  ? required for TX-back
                //  CR[0]   = 1  UE  UART enable
                //  With default parity params: CR = 0x37
                // ------------------------------------------------
                UART_control_reg : begin
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    p_w_data <= {24'h00_0000,
                                 2'b00,
                                 UART_parity_sel,
                                 UART_parity_en,
                                 4'b0111};  // M=0, RE=1, TE=1, UE=1
                    p_addr   <= UART_BASE_ADDR + control_reg_addr;
                end

                // ------------------------------------------------
                //  UART_send_byte  - write HANDSHAKE_BYTE to TDR (0x08)
                //  TDR[8:0]: bit 8 forced 0 (8-bit word mode, M=0)
                // ------------------------------------------------
                UART_send_byte : begin
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    p_w_data <= {23'd0, 1'b0, HANDSHAKE_BYTE};
                    p_addr   <= UART_BASE_ADDR + transfer_addr;
                end

                // ------------------------------------------------
                //  UART_poll_tc  - poll SR until TC (SR[2]) = 1
                //  Writing TDR cleared TC; TC re-asserts only after
                //  the full stop-bit has shifted out.
                // ------------------------------------------------
                UART_poll_tc : begin
                    p_write <= 1'b0;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    p_addr  <= UART_BASE_ADDR + SR_addr;
                end

                // ------------------------------------------------
                //  UART_recv_ack  - receive one ack byte
                //
                //  Phase A (reading_rdr=0): read SR.
                //    RXNE (SR[1]) ? set reading_rdr, point at RDR.
                //
                //  Phase B (reading_rdr=1): read RDR.
                //    Latch byte into ack_recv, pulse ack_received,
                //    switch back to SR address for UART_receive.
                // ------------------------------------------------
                UART_recv_ack : begin
                    p_write      <= 1'b0;
                    penable      <= 1'b1;
                    psel         <= 1'b1;
                    ack_received <= 1'b0;

                    if (reading_rdr) begin
                        // Phase B
                        reading_rdr  <= 1'b0;
                        ack_recv     <= p_r_data[7:0];
                        ack_received <= 1'b1;
                        p_addr       <= UART_BASE_ADDR + SR_addr;
                    end
                    else begin
                        // Phase A
                        if (p_r_data[1]) begin   // RXNE
                            reading_rdr <= 1'b1;
                            p_addr      <= UART_BASE_ADDR + RDR_addr;
                        end
                        else
                            p_addr <= UART_BASE_ADDR + SR_addr;
                    end
                end

                // ------------------------------------------------
                //  UART_receive  - pack bytes ? words ? rx_mem[]
                //
                //  Phase A (reading_rdr=0):
                //    If mem_send_fully_loaded=1 (set previous Phase B
                //    when counter was 3): out_send_data is fully valid
                //    ? write rx_mem[mem_write_ptr], increment pointer.
                //    Clear mem_send_fully_loaded.
                //    Accumulate idle counter on SR[3]=RXIDLE.
                //    Switch to Phase B on SR[1]=RXNE.
                //
                //  Phase B (reading_rdr=1):
                //    Latch p_r_data[7:0] into out_send_data slice.
                //    On counter==3 set mem_send_fully_loaded.
                //    Reset reading_rdr; return address to SR.
                // ------------------------------------------------
                UART_receive : begin
                    p_write <= 1'b0;
                    penable <= 1'b1;
                    psel    <= 1'b1;

                    if (reading_rdr) begin
                        // ---- Phase B ----
                        reading_rdr <= 1'b0;
                        counter_2   <= 9'd0;

                        case (counter)
                            2'b00 : begin
                                out_send_data[31:24] <= p_r_data[7:0];
                                counter              <= 2'b01;
                                mem_send_fully_loaded <= 1'b0;
                            end
                            2'b01 : begin
                                out_send_data[23:16] <= p_r_data[7:0];
                                counter              <= 2'b10;
                            end
                            2'b10 : begin
                                out_send_data[15:8]  <= p_r_data[7:0];
                                counter              <= 2'b11;
                            end
                            2'b11 : begin
                                // 4th byte: word complete
                                out_send_data[7:0]    <= p_r_data[7:0];
                                mem_send_fully_loaded <= 1'b1; // write_data_en HIGH
                                counter               <= 2'b00;
                            end
                        endcase

                        p_addr <= UART_BASE_ADDR + SR_addr;
                    end
                    else begin
                        // ---- Phase A ----

                        // Commit completed word to internal storage.
                        // mem_send_fully_loaded=1 means last Phase B was
                        // counter==3: out_send_data has all 4 bytes valid.
                        if (mem_send_fully_loaded &&
                            (mem_write_ptr < MEM_DEPTH)) begin
                            rx_mem[mem_write_ptr] <= out_send_data;
                            mem_write_ptr         <= mem_write_ptr + 8'd1;
                        end

                        mem_send_fully_loaded <= 1'b0; // clear after one cycle

                        // Idle counter
                        if (p_r_data[3])
                            counter_2 <= counter_2 + 9'd1;
                        else
                            counter_2 <= 9'd0;

                        // RXNE check
                        if (p_r_data[1]) begin
                            reading_rdr <= 1'b1;
                            p_addr      <= UART_BASE_ADDR + RDR_addr;
                        end
                        else
                            p_addr <= UART_BASE_ADDR + SR_addr;
                    end
                end // UART_receive

                // ------------------------------------------------
                //  UART_tx_start  - initialise TX-back pointers
                //
                //  Load rx_mem[0] into tx_word.
                //  mem_read_ptr = 1  (next word index after first).
                //  tx_byte_sel  = 0  (MSB first).
                //  next_state goes to finished if nothing was received.
                // ------------------------------------------------
                UART_tx_start : begin
                    p_write      <= 1'b0;
                    penable      <= 1'b0;
                    psel         <= 1'b0;
                    tx_word      <= rx_mem[0];
                    mem_read_ptr <= 8'd1;
                    tx_byte_sel  <= 2'b00;
                end

                // ------------------------------------------------
                //  UART_tx_load  - write one byte to TDR (0x08)
                //
                //  tx_byte_sel selects which byte of tx_word to send:
                //    0 ? tx_word[31:24]  (MSB)
                //    1 ? tx_word[23:16]
                //    2 ? tx_word[15:8]
                //    3 ? tx_word[7:0]   (LSB)
                //
                //  Writing TDR clears TC in UART_module, so the first
                //  SR read in UART_tx_wait will not see a stale TC=1.
                // ------------------------------------------------
                UART_tx_load : begin
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    p_addr   <= UART_BASE_ADDR + transfer_addr;
                    case (tx_byte_sel)
                        2'b00 : p_w_data <= {23'd0, 1'b0, tx_word[31:24]};
                        2'b01 : p_w_data <= {23'd0, 1'b0, tx_word[23:16]};
                        2'b10 : p_w_data <= {23'd0, 1'b0, tx_word[15:8]};
                        2'b11 : p_w_data <= {23'd0, 1'b0, tx_word[7:0]};
                    endcase
                end

                // ------------------------------------------------
                //  UART_tx_wait  - poll SR[2] (TC) between bytes
                //
                //  TC=1 (frame done):
                //    tx_byte_sel != 3  ? more bytes in this word:
                //      increment tx_byte_sel.
                //    tx_byte_sel == 3  ? word boundary:
                //      wrap tx_byte_sel to 0.
                //      If more words (mem_read_ptr < mem_write_ptr):
                //        load rx_mem[mem_read_ptr] ? tx_word,
                //        increment mem_read_ptr.
                //      else: housekeeping only; next_state = finished.
                //
                //  next_state (combinational) sees the PRE-increment
                //  values of tx_byte_sel / mem_read_ptr and decides
                //  the transition before the sequential update takes
                //  effect on the same rising edge.
                // ------------------------------------------------
                UART_tx_wait : begin
                    p_write <= 1'b0;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    p_addr  <= UART_BASE_ADDR + SR_addr;

                    if (p_r_data[2]) begin          // TC: byte frame done
                        if (tx_byte_sel == 2'b11) begin
                            // All 4 bytes of current word sent
                            tx_byte_sel <= 2'b00;
                            if (mem_read_ptr < mem_write_ptr) begin
                                tx_word      <= rx_mem[mem_read_ptr];
                                mem_read_ptr <= mem_read_ptr + 8'd1;
                            end
                            // else: last word done; next_state = finished
                        end
                        else begin
                            tx_byte_sel <= tx_byte_sel + 2'd1;
                        end
                    end
                end // UART_tx_wait

                // ------------------------------------------------
                //  finished  - release CPU from reset
                // ------------------------------------------------
                finished : begin
                    reset_cpu <= 1'b1;
                end

            endcase
        end
    end

endmodule*/