// Bootloader module for receiving program instructions over UART and writing to memory
module boot_loader #(
    parameter UART_BASE_ADDR  = 32'h0000_2040,
    parameter UART_baud_rate  = 32'd27,         // BRR=27 for correct baud
    parameter UART_parity_sel = 1'b0,           // 0=even, 1=odd  -> CR[5]
    parameter UART_parity_en  = 1'b0,           // parity enable  -> CR[4]
    parameter HANDSHAKE_BYTE  = 8'hAA,          // byte sent to signal sender to start
    parameter ACK_BYTE        = 8'h55           // expected ack byte from sender
)(
    input         clk, resetn,   // MCU-wide reset, active-low
    input         boot_select,   // activate UART path when high
    output reg    cpu_resetn,    // CPU reset; active-low during boot, high when done

    // APB master interface (connects to uart_top)
    input      [31:0] prdata,  // prdata from uart_top
    output reg [31:0] paddr,    // APB address
    output reg [31:0] pwdata,  // APB write data
    output reg        psel,
    output reg        penable,
    input             pready,    // ignored (uart_top always-ready)
    output reg        pwrite,
    input             pslverr,   // ignored
    output reg        presetn,   // APB reset to uart_top (active-low)

    // Word-ready interface to memory controller
    output reg [31:0] out_send_data,  // packed 32-bit instruction word
    output reg [31:0] out_send_addr,  // address for the current out_send_data
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
    //  UART_poll_tc  : prdata[2] = SR[2] = TC (Transmission Complete).
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
            IDLE             : next_state = boot_select ? UART_BRR_set : IDLE;
            UART_BRR_set     : next_state = UART_control_reg;
            UART_control_reg : next_state = UART_send_byte;      // -> handshake TX

            // Send HANDSHAKE_BYTE: one-cycle APB write to TDR then move on
            UART_send_byte   : next_state = UART_poll_tc;

            // Stay here until TC (SR[2]) goes high -> TX frame fully sent
            UART_poll_tc     : next_state = prdata[2] ? UART_recv_ack
                                                         : UART_poll_tc;

            // Wait until Phase B completes and ack_received pulses high
            UART_recv_ack    : next_state = ack_received ? UART_receive
                                                         : UART_recv_ack;

            UART_receive     : next_state =
                                  (!reading_rdr &&
                                   prdata[3]  &&
                                   counter_2 >= IDLE_THRESHOLD)
                                  ? finished : UART_receive;

            finished         : next_state = (~resetn) ? IDLE : finished;
            default          : next_state = IDLE;
        endcase
    end

    // ----------------------------------------------------------
    //  Sequential logic
    // ----------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cpu_resetn            <= 1'b0;   // hold CPU in reset (active-low)
            presetn               <= 1'b0;   // assert APB reset to uart_top
            curr_state            <= IDLE;
            counter               <= 2'b00;
            counter_2             <= 9'd0;
            mem_send_fully_loaded <= 1'b0;
            reading_rdr           <= 1'b0;
            ack_recv              <= 8'h00;
            ack_received          <= 1'b0;
            ack_ok                <= 1'b0;
            pwrite                <= 1'b0;
            penable               <= 1'b0;
            psel                  <= 1'b0;
            pwdata                <= 32'd0;
            paddr                 <= 32'hFFFF_FFFF;
            out_send_data         <= 32'd0;
            out_send_addr         <= 32'hFFFF_FFFC; // pre-decremented: first word → addr 0
        end
        else begin
            curr_state <= next_state;
            mem_send_fully_loaded <= 1'b0;
            case (curr_state)

                // --------------------------------------------------
                //  IDLE - release APB reset, quiesce bus
                // --------------------------------------------------
                IDLE : begin
                    presetn               <= 1'b1;
                    pwrite               <= 1'b0;
                    penable               <= 1'b0;
                    psel                  <= 1'b0;
                    pwdata              <= 32'd0;
                    paddr                <= 32'hFFFF_FFFF;
                    counter               <= 2'b00;
                    counter_2             <= 9'd0;
                    mem_send_fully_loaded <= 1'b0;
                    reading_rdr           <= 1'b0;
                    ack_recv              <= 8'h00;
                    ack_received          <= 1'b0;
                    ack_ok                <= 1'b0;
                    out_send_data         <= 32'd0;
                    out_send_addr         <= 32'hFFFF_FFFC; // pre-decremented: first word → addr 0
                end

                // --------------------------------------------------
                //  UART_BRR_set - write baud-rate register (BRR)
                //  APB WRITE  paddr = BASE + 0x10
                //             pwdata = UART_baud_rate (=27 default)
                // --------------------------------------------------
                UART_BRR_set : begin
                    pwrite  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    pwdata <= UART_baud_rate;
                    paddr   <= UART_BASE_ADDR + baud_rate_addr;
                end

                // --------------------------------------------------
                //  UART_control_reg - write control register (CR)
                //  APB WRITE  paddr = BASE + 0x0C
                //
                //  pwdata[7:0]:
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
                    pwrite  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    pwdata <= {24'h00_0000,
                                 2'b00,
                                 UART_parity_sel,
                                 UART_parity_en,
                                 4'b0111};   // M=0, RE=1, TE=1, UE=1
                    paddr   <= UART_BASE_ADDR + control_reg_addr;
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
                //  pwdata = {23'd0, 1'b0, HANDSHAKE_BYTE}
                // --------------------------------------------------
                UART_send_byte : begin
                    pwrite  <= 1'b1;
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    pwdata <= {23'd0, 1'b0, HANDSHAKE_BYTE};
                    paddr   <= UART_BASE_ADDR + transfer_addr;
                    // Next state: UART_poll_tc (next_state already set combinationally)
                end

                // --------------------------------------------------
                //  UART_poll_tc (NEW)
                //
                //  Poll SR continuously; wait until TC (SR[2]) = 1,
                //  indicating the HANDSHAKE_BYTE frame has been fully
                //  shifted out onto the TX line.
                //
                //  prdata holds SR from the PREVIOUS cycle's read,
                //  so the first SR sample arrives on the cycle after
                //  entering this state.  TC will only assert after many
                //  baud-clock cycles, so the one-cycle pipeline delay
                //  is inconsequential.
                //
                //  pwrite = 0 (read-only).
                //  paddr  = SR_addr held constant throughout.
                // --------------------------------------------------
                UART_poll_tc : begin
                    pwrite <= 1'b0;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    paddr  <= UART_BASE_ADDR + SR_addr;
                    // next_state transitions to UART_recv_ack when
                    // prdata[2] (TC) is seen by the combinational block.
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
                //    Read RDR at 0x04.  Latch prdata[7:0] into
                //    ack_recv, compare with ACK_BYTE, set ack_ok.
                //    Pulse ack_received high for one cycle so that
                //    next_state (combinational) advances to UART_receive.
                //
                //  After ack_received pulses, clear it so subsequent
                //  re-entries to this state (after a resetn) start
                //  fresh.
                // --------------------------------------------------
                UART_recv_ack : begin
                    pwrite      <= 1'b0;
                    penable      <= 1'b1;
                    psel         <= 1'b1;
                    ack_received <= 1'b0; // clear unless Phase B completes below

                    if (reading_rdr) begin
                        // -----------------------------------------------
                        //  Phase B: prdata now holds the fresh RDR byte
                        // -----------------------------------------------
                        reading_rdr  <= 1'b0;

                        // Latch ack and verify
                        ack_recv     <= prdata[7:0];
                        ack_ok       <= (prdata[7:0] == ACK_BYTE);

                        // Pulse ack_received so next_state sees UART_receive
                        ack_received <= 1'b1;

                        // Return address to SR for UART_receive's first cycle
                        paddr <= UART_BASE_ADDR + SR_addr;
                    end
                    else begin
                        // -----------------------------------------------
                        //  Phase A: read SR this cycle
                        //  prdata holds last cycle's SR result
                        // -----------------------------------------------
                        if (prdata[1]) begin  // SR[1] = RXNE: ack byte ready
                            reading_rdr <= 1'b1;
                            paddr      <= UART_BASE_ADDR + RDR_addr; // Phase B
                        end
                        else begin
                            paddr <= UART_BASE_ADDR + SR_addr; // keep polling SR
                        end
                    end
                end // UART_recv_ack

                // --------------------------------------------------
                //  UART_receive - poll for bytes, pack into 32-bit words
                //
                //  Two-phase APB-read cycle per byte:
                //
                //  Phase A (reading_rdr == 0)  :  read SR at 0x00
                //    prdata = {24'd0, SR[7:0]}
                //    SR[1] = RXNE  - new byte in RDR
                //    SR[3] = RXIDLE - RX line idle (no activity)
                //
                //    -> If RXNE=1: set reading_rdr, next cycle read RDR
                //    -> Accumulate idle counter on SR[3]; reset on activity
                //    -> Clear mem_send_fully_loaded (was high only last cycle)
                //
                //  Phase B (reading_rdr == 1)  :  read RDR at 0x04
                //    prdata = {23'd0, RDR[8:0]}
                //    prdata[7:0] = received byte (8-bit mode)
                //
                //    -> Latch into out_send_data slice based on counter
                //    -> After 4th byte: set mem_send_fully_loaded (one cycle)
                //       write_data_en pulses high; out_send_data is complete
                //    -> Clear reading_rdr; return to Phase A (SR read)
                //
                //  pwrite stays 0 throughout; memory controller uses
                //  out_send_data / write_data_en directly.
                // --------------------------------------------------
                UART_receive : begin
                    pwrite <= 1'b0;  // bootloader never writes in receive phase
                    penable <= 1'b1;
                    psel    <= 1'b1;

                    if (reading_rdr) begin
                        // -----------------------------------------------
                        //  Phase B: prdata now holds the fresh RDR byte
                        // -----------------------------------------------
                        reading_rdr <= 1'b0;
                        counter_2   <= 9'd0; // activity detected - reset idle ctr

                        // Latch byte into the correct word slice
                        case (counter)
                            2'b00 : begin
                                out_send_data[31:24] <= prdata[7:0];
                                counter              <= 2'b01;
                                mem_send_fully_loaded <= 1'b0;
                            end

                            2'b01 : begin
                                out_send_data[23:16] <= prdata[7:0];
                                counter              <= 2'b10;
                            end

                            2'b10 : begin
                                out_send_data[15:8]  <= prdata[7:0];
                                counter              <= 2'b11;
                            end

                            2'b11 : begin
                                // 4th byte: complete the word and pulse write_data_en
                                out_send_data[7:0]    <= prdata[7:0];
                                out_send_addr         <= out_send_addr + 'd4; // for writing to memory
                                mem_send_fully_loaded <= 1'b1; // write_data_en goes HIGH
                                counter               <= 2'b00; // reset for next word
                            end
                        endcase

                        // Return to SR read next cycle
                        paddr <= UART_BASE_ADDR + SR_addr;
                    end
                    else begin
                        // -----------------------------------------------
                        //  Phase A: read SR this cycle
                        //  prdata holds last cycle's SR result
                        // -----------------------------------------------

                        // Clear the one-cycle write_data_en pulse
                        mem_send_fully_loaded <= 1'b0;

                        // Idle counter: increment while RX line is idle
                        if (prdata[3])       // SR[3] = RXIDLE
                            counter_2 <= counter_2 + 1;
                        else
                            counter_2 <= 9'd0;

                        // RXNE check: if new byte ready, switch to RDR read
                        if (prdata[1]) begin // SR[1] = RXNE
                            reading_rdr <= 1'b1;
                            paddr      <= UART_BASE_ADDR + RDR_addr; // Phase B address
                        end
                        else begin
                            paddr <= UART_BASE_ADDR + SR_addr; // stay on SR
                        end
                    end
                end // UART_receive

                // --------------------------------------------------
                //  finished - release CPU from reset
                // --------------------------------------------------
                finished : begin
                    cpu_resetn <= 1'b1; // de-assert CPU reset (active-low design)
                end
            endcase
        end
    end

endmodule
