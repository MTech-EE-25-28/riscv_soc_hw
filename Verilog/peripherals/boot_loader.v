// =============================================================================
//  boot_loader.v
//
//  UART bootloader FSM.  On power-on (boot_select=1):
//    1. Configures uart_top: BRR → CR (no parity, 8-bit, RE+TE+UE).
//    2. Sends HANDSHAKE_BYTE (0xAA) over TX, waits for TC.
//    3. Waits for ACK_BYTE (0x55) on RX.
//    4. Receives a byte-stream, packs every 4 bytes (MSB-first) into a
//       32-bit word, pulses write_data_en for one cycle, then sends 'X'
//       (0x58) over TX to acknowledge the word.
//    5. After IDLE_THRESHOLD consecutive SR-idle polls with no new byte,
//       asserts cpu_resetn to release the CPU.
//
//  APB register map (offset from UART_BASE_ADDR):
//    0x00  SR   read-only   SR[3]=RXIDLE  SR[2]=TC  SR[1]=RXNE  SR[0]=TXE
//    0x04  RDR  read-only   received byte in [7:0]
//    0x08  TDR  write-only  byte to transmit in [7:0]
//    0x0C  CR   write-once  {2'b00, PS, PCE, M, RE, TE, UE}
//    0x10  BRR  write-once  baud-rate divisor
// =============================================================================
module boot_loader #(
    parameter UART_BASE_ADDR  = 32'h0000_2040,
    parameter UART_baud_rate  = 32'd27,   // BRR: 1 bit = 27 × 16 clocks at 50 MHz
    parameter UART_parity_sel = 1'b0,     // CR[5] PS:  0=even, 1=odd
    parameter UART_parity_en  = 1'b0,     // CR[4] PCE: 0=disabled
    parameter HANDSHAKE_BYTE  = 8'hAA,    // sent to host to start transfer
    parameter ACK_BYTE        = 8'h55     // expected reply from host
)(
    input         clk,
    input         resetn,       // system reset, active-low
    input         boot_select,  // start boot when high

    output reg    cpu_resetn,   // holds CPU in reset (0) during boot

    // APB master port → uart_top
    input      [31:0] prdata,
    output reg [31:0] paddr,
    output reg [31:0] pwdata,
    output reg        psel,
    output reg        penable,
    input             pready,
    output reg        pwrite,
    input             pslverr,
    output reg        presetn,  // APB reset to uart_top, active-low

    // Word output to memory controller
    output reg [31:0] out_send_data,  // complete 32-bit word (valid when write_data_en=1)
    output reg [31:0] out_send_addr,  // word address (word 0 at 0x0000_0000)
    output            write_data_en   // 1-cycle pulse when out_send_data is valid
);

    // -------------------------------------------------------------------------
    //  State encoding
    // -------------------------------------------------------------------------
    localparam [3:0]
        IDLE              = 4'b0000,
        UART_BRR_set      = 4'b1001,  // write BRR
        UART_control_reg  = 4'b1010,  // write CR
        UART_send_byte    = 4'b1100,  // write HANDSHAKE_BYTE to TDR
        UART_poll_tc      = 4'b1101,  // wait for TC (handshake TX complete)
        UART_recv_ack     = 4'b1110,  // wait for ACK_BYTE from host
        UART_receive      = 4'b1011,  // receive bytes → pack into words
        UART_send_word_ack = 4'b0001, // write 'X' to TDR after each word
        UART_poll_word_tc  = 4'b0010, // wait for TC ('X' TX complete)
        FINISHED          = 4'b1111;  // boot done, release CPU

    // -------------------------------------------------------------------------
    //  APB offsets
    // -------------------------------------------------------------------------
    localparam SR_ADDR   = 8'h00;
    localparam RDR_ADDR  = 8'h04;
    localparam TDR_ADDR  = 8'h08;
    localparam CR_ADDR   = 8'h0C;
    localparam BRR_ADDR  = 8'h10;

    localparam [10:0] WORD_COUNT = 10'd1535;  // finish after receiving this many words

    // -------------------------------------------------------------------------
    //  Registers
    // -------------------------------------------------------------------------
    reg [3:0] curr_state, next_state;

    reg        mem_send_fully_loaded;
    reg [1:0]  counter;     // byte index within current word (0-3)
    reg [10:0] word_cnt;    // number of complete words received
    reg        reading_rdr; // 1 = next prdata holds RDR byte

    reg [7:0]  ack_recv;
    reg        ack_received;
    reg        ack_ok;

    assign write_data_en = mem_send_fully_loaded;

    // -------------------------------------------------------------------------
    //  Next-state logic
    // -------------------------------------------------------------------------
    always @(*) begin
        case (curr_state)
            IDLE             : next_state = boot_select  ? UART_BRR_set     : IDLE;
            UART_BRR_set     : next_state = UART_control_reg;
            UART_control_reg : next_state = UART_send_byte;
            UART_send_byte   : next_state = UART_poll_tc;
            UART_poll_tc     : next_state = prdata[2]   ? UART_recv_ack     : UART_poll_tc;
            UART_recv_ack    : next_state = ack_received ? UART_receive      : UART_recv_ack;
            UART_receive     : next_state = (mem_send_fully_loaded && word_cnt >= WORD_COUNT) ? FINISHED :
                                            mem_send_fully_loaded            ? UART_send_word_ack : UART_receive;
            UART_send_word_ack : next_state = UART_poll_word_tc;
            UART_poll_word_tc  : next_state = prdata[2] ? UART_receive       : UART_poll_word_tc;
            FINISHED           : next_state = (~resetn) ? IDLE               : FINISHED;
            default            : next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    //  Sequential logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cpu_resetn            <= 1'b0;
            presetn               <= 1'b0;
            curr_state            <= IDLE;
            counter               <= 2'b00;
            word_cnt              <= 10'd0;
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
            out_send_addr         <= 32'hFFFF_FFFC; // pre-decremented; first +4 → 0x0
        end else begin
            curr_state            <= next_state;
            mem_send_fully_loaded <= 1'b0; // default: cleared every cycle

            case (curr_state)

                // -------------------------------------------------------------
                IDLE : begin
                    presetn      <= 1'b1;
                    pwrite       <= 1'b0;
                    penable      <= 1'b0;
                    psel         <= 1'b0;
                    pwdata       <= 32'd0;
                    paddr        <= 32'hFFFF_FFFF;
                    counter      <= 2'b00;
                    word_cnt     <= 10'd0;
                    reading_rdr  <= 1'b0;
                    ack_recv     <= 8'h00;
                    ack_received <= 1'b0;
                    ack_ok       <= 1'b0;
                    out_send_data <= 32'd0;
                    out_send_addr <= 32'hFFFF_FFFC;
                end

                // -------------------------------------------------------------
                UART_BRR_set : begin
                    pwrite  <= 1'b1;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    pwdata  <= UART_baud_rate;
                    paddr   <= UART_BASE_ADDR + BRR_ADDR;
                end

                // -------------------------------------------------------------
                // CR: {2'b00, PS, PCE, M=0, RE=1, TE=1, UE=1}
                // -------------------------------------------------------------
                UART_control_reg : begin
                    pwrite  <= 1'b1;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    pwdata  <= {24'd0, 2'b00, UART_parity_sel, UART_parity_en, 4'b0111};
                    paddr   <= UART_BASE_ADDR + CR_ADDR;
                end

                // -------------------------------------------------------------
                // Write HANDSHAKE_BYTE to TDR
                // -------------------------------------------------------------
                UART_send_byte : begin
                    pwrite  <= 1'b1;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    pwdata  <= {24'd0, HANDSHAKE_BYTE};
                    paddr   <= UART_BASE_ADDR + TDR_ADDR;
                end

                // -------------------------------------------------------------
                // Poll SR until TC (SR[2]) = 1
                // -------------------------------------------------------------
                UART_poll_tc : begin
                    pwrite  <= 1'b0;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    paddr   <= UART_BASE_ADDR + SR_ADDR;
                end

                // -------------------------------------------------------------
                // Two-phase: read SR (Phase A) then RDR (Phase B) for ack byte
                // -------------------------------------------------------------
                UART_recv_ack : begin
                    pwrite       <= 1'b0;
                    penable      <= 1'b1;
                    psel         <= 1'b1;
                    ack_received <= 1'b0;

                    if (reading_rdr) begin   // Phase B: prdata = RDR
                        reading_rdr  <= 1'b0;
                        ack_recv     <= prdata[7:0];
                        ack_ok       <= (prdata[7:0] == ACK_BYTE);
                        ack_received <= 1'b1;
                        paddr        <= UART_BASE_ADDR + SR_ADDR;
                    end else begin           // Phase A: prdata = SR
                        if (prdata[1]) begin // RXNE set
                            reading_rdr <= 1'b1;
                            paddr       <= UART_BASE_ADDR + RDR_ADDR;
                        end else
                            paddr <= UART_BASE_ADDR + SR_ADDR;
                    end
                end

                // -------------------------------------------------------------
                // Two-phase: read SR (Phase A) then RDR (Phase B) for each byte.
                // Every 4th byte completes a word → pulse write_data_en.
                // -------------------------------------------------------------
                UART_receive : begin
                    pwrite  <= 1'b0;
                    penable <= 1'b1;
                    psel    <= 1'b1;

                    if (reading_rdr) begin   // Phase B: prdata = RDR
                        reading_rdr <= 1'b0;
                        paddr       <= UART_BASE_ADDR + SR_ADDR;

                        case (counter)
                            2'b00: begin out_send_data[31:24] <= prdata[7:0]; counter <= 2'b01; end
                            2'b01: begin out_send_data[23:16] <= prdata[7:0]; counter <= 2'b10; end
                            2'b10: begin out_send_data[15:8]  <= prdata[7:0]; counter <= 2'b11; end
                            2'b11: begin
                                out_send_data[7:0]    <= prdata[7:0];
                                out_send_addr         <= out_send_addr + 'd4;
                                mem_send_fully_loaded <= 1'b1;
                                word_cnt              <= word_cnt + 10'd1;
                                counter               <= 2'b00;
                            end
                        endcase
                    end else begin           // Phase A: prdata = SR
                        if (prdata[1]) begin // RXNE set
                            reading_rdr <= 1'b1;
                            paddr       <= UART_BASE_ADDR + RDR_ADDR;
                        end else
                            paddr <= UART_BASE_ADDR + SR_ADDR;
                    end
                end

                // -------------------------------------------------------------
                // Send 'X' (0x58) to acknowledge the received word
                // -------------------------------------------------------------
                UART_send_word_ack : begin
                    pwrite      <= 1'b1;
                    penable     <= 1'b1;
                    psel        <= 1'b1;
                    pwdata      <= {24'd0, 8'h58};
                    paddr       <= UART_BASE_ADDR + TDR_ADDR;
                    reading_rdr <= 1'b0;
                end

                // -------------------------------------------------------------
                // Wait for TC before returning to UART_receive
                // -------------------------------------------------------------
                UART_poll_word_tc : begin
                    pwrite  <= 1'b0;
                    penable <= 1'b1;
                    psel    <= 1'b1;
                    paddr   <= UART_BASE_ADDR + SR_ADDR;
                end

                // -------------------------------------------------------------
                // Boot complete — release CPU
                // -------------------------------------------------------------
                FINISHED : begin
                    cpu_resetn <= 1'b1;
                end

            endcase
        end
    end

endmodule