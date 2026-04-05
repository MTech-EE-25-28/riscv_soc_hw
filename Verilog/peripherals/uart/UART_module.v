`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04.04.2026 15:29:57
// Design Name:
// Module Name: UART_module
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module UART_module (
    input wire clk,
    input wire reset,

    // UART Physical Lines
    input wire rx,
    output reg tx,

    // Register Inputs & Enables
    input wire [15:0] BRR_in,
    input wire BRR_en,

    input wire [7:0] CR_in,
    input wire CR_en,

    input wire [8:0] TDR_in,
    input wire TDR_en,

    input wire RDR_ren,

    // Register Outputs
    output wire [7:0] SR_out,
    output wire [8:0] RDR_out
);

    // ==========================================
    // 1. Control & Baud Registers
    // ==========================================
    reg [7:0] CR1_reg;
    always @(posedge clk or posedge reset) begin
        if (reset) CR1_reg <= 8'd0;
        else if (CR_en) CR1_reg <= CR_in;
    end

    wire IE_RXNE = CR1_reg[7];
    wire IE_TXE  = CR1_reg[6];
    wire PS      = CR1_reg[5];
    wire PCE     = CR1_reg[4];
    wire M       = CR1_reg[3];
    wire RE      = CR1_reg[2];
    wire TE      = CR1_reg[1];
    wire UE      = CR1_reg[0];

    reg [15:0] BRR_reg;
    always @(posedge clk or posedge reset) begin
        if (reset) BRR_reg <= 16'd0;
        else if (BRR_en) BRR_reg <= BRR_in;
    end

    wire baud_tick_16x;
    baud_rate_gen baud_gen_inst (
        .clk(clk),
        .reset(reset),
        .baud_rate_reg(BRR_reg),
        .baud_tick(baud_tick_16x)
    );

    // ==========================================
    // 2. Status & Data Registers (Synchronous Updates)
    // ==========================================
    reg ne_flag, fe_flag, pe_flag, owe_flag;
    reg idle_flag, tc_flag, rxne_flag, txe_flag;

    assign SR_out = {ne_flag, fe_flag, pe_flag, owe_flag, idle_flag, tc_flag, rxne_flag, txe_flag};

    reg [8:0] TDR_reg;
    reg [8:0] RDR_reg;
    assign RDR_out = RDR_reg;

    // Handshake pulses from FSMs
    wire load_tdr_to_shift;
    wire tx_frame_done;
    wire rx_frame_done;

    // --- TX Path Registers & Flags ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            TDR_reg <= 9'd0;
            txe_flag <= 1'b1;
            tc_flag <= 1'b0;
        end else if (UE && TE) begin
            // Data loading
            if (TDR_en) begin
                TDR_reg <= TDR_in;
                txe_flag <= 1'b0;
            end else if (load_tdr_to_shift) begin
                txe_flag <= 1'b1; // Instant update when loaded to shift reg
            end

            // Transmission Complete
            if (load_tdr_to_shift) begin
                tc_flag <= 1'b0;
            end else if (tx_frame_done) begin
                tc_flag <= 1'b1;
            end
        end else begin
            txe_flag <= 1'b1;
            tc_flag <= 1'b0;
        end
    end

    // --- RX Path Registers & Flags ---
//    wire temp_ne_pulse; // Driven by RX FSM
    reg temp_ne_flag;

    // ==========================================
    // 3. Transmitter FSM
    // ==========================================
    localparam TX_IDLE = 3'd0, TX_START = 3'd1, TX_DATA = 3'd2, TX_PARITY = 3'd3, TX_STOP = 3'd4;
    reg [2:0] tx_state;
    reg [3:0] tx_s_tick_cnt;
    reg [3:0] tx_bit_ptr;
    reg [8:0] tx_shift_reg;

    assign load_tdr_to_shift = (tx_state == TX_IDLE) && (!txe_flag) && baud_tick_16x;
    assign tx_frame_done = (tx_state == TX_STOP) && (tx_s_tick_cnt == 15) && baud_tick_16x;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_state <= TX_IDLE; tx <= 1'b1; tx_s_tick_cnt <= 0;
            tx_bit_ptr <= 0; tx_shift_reg <= 0;
        end else if (UE && TE) begin
            if (baud_tick_16x) begin
                case (tx_state)
                    TX_IDLE: begin
                        tx <= 1'b1;
                        if (!txe_flag) begin
                            tx_shift_reg <= TDR_reg;
                            tx_state <= TX_START;
                            tx_s_tick_cnt <= 0;
                        end
                    end
                    TX_START: begin
                        tx <= 1'b0;
                        if (tx_s_tick_cnt == 15) begin
                            tx_s_tick_cnt <= 0;
                            tx_state <= TX_DATA;
                            tx_bit_ptr <= 0;
                        end else tx_s_tick_cnt <= tx_s_tick_cnt + 1;
                    end
                    TX_DATA: begin
                        tx <= tx_shift_reg[tx_bit_ptr];
                        if (tx_s_tick_cnt == 15) begin
                            tx_s_tick_cnt <= 0;
                            if (tx_bit_ptr == (M ? 4'd8 : 4'd7)) begin
                                tx_state <= PCE ? TX_PARITY : TX_STOP;
                            end else tx_bit_ptr <= tx_bit_ptr + 1;
                        end else tx_s_tick_cnt <= tx_s_tick_cnt + 1;
                    end
//                    TX_PARITY: begin
//                        tx <= PS ^ (^tx_shift_reg[7:0]);
//                        if (tx_s_tick_cnt == 15) begin
//                            tx_s_tick_cnt <= 0;
//                            tx_state <= TX_STOP;
//                        end else tx_s_tick_cnt <= tx_s_tick_cnt + 1;
//                    end
                    TX_PARITY: begin // Dynamically calculate outgoing parity based on M
                        tx <= PS ^ (M ? ^tx_shift_reg[8:0] : ^tx_shift_reg[7:0]);
                        if (tx_s_tick_cnt == 15) begin
                            tx_s_tick_cnt <= 0;
                            tx_state <= TX_STOP;
                        end else tx_s_tick_cnt <= tx_s_tick_cnt + 1;
                    end
                    TX_STOP: begin
                        tx <= 1'b1;
                        if (tx_s_tick_cnt == 15) begin
                            tx_state <= TX_IDLE;
                        end else tx_s_tick_cnt <= tx_s_tick_cnt + 1;
                    end
                endcase
            end
        end else begin
            tx_state <= TX_IDLE;
            tx <= 1'b1;
        end
    end

    // ==========================================
    // 4. Receiver FSM & Majority Vote
    // ==========================================
    localparam RX_IDLE = 3'd0, RX_START = 3'd1, RX_DATA = 3'd2, RX_PARITY = 3'd3, RX_STOP = 3'd4;
    reg [2:0] rx_state;
    reg [3:0] rx_s_tick_cnt;
    reg [3:0] rx_bit_ptr;
    reg [8:0] rx_shift_reg;
    reg [2:0] rx_samples;
    reg rx_parity_bit;
    reg [7:0] idle_timeout;

    wire decoded_bit = (rx_samples[0] & rx_samples[1]) |
                       (rx_samples[1] & rx_samples[2]) |
                       (rx_samples[0] & rx_samples[2]);

    wire samples_mixed = (rx_samples != 3'b000) && (rx_samples != 3'b111);
    assign rx_frame_done = (rx_state == RX_STOP) && (rx_s_tick_cnt == 15) && baud_tick_16x;


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RDR_reg <= 9'd0;
            rxne_flag <= 1'b0;
            {ne_flag, fe_flag, pe_flag, owe_flag} <= 4'd0;
        end else if (UE && RE) begin
            if (RDR_ren) begin
                rxne_flag <= 1'b0;
            end

            if (rx_frame_done) begin
                RDR_reg <= rx_shift_reg;
                rxne_flag <= 1'b1;

                // Update all status flags synchronously with RDR
                ne_flag <= temp_ne_flag | samples_mixed;

                if (decoded_bit == 1'b0) fe_flag <= 1'b1;
                else fe_flag <= 1'b0;

//                if (PCE) begin
//                    if ((PS ^ (^rx_shift_reg[7:0])) != rx_parity_bit) pe_flag <= 1'b1;
//                    else pe_flag <= 1'b0;
//                end

                if (PCE) begin
                    // Use ternary operator to select 9-bit or 8-bit XOR reduction
                    if ((PS ^ (M ? ^rx_shift_reg[8:0] : ^rx_shift_reg[7:0])) != rx_parity_bit)
                        pe_flag <= 1'b1;
                    else
                        pe_flag <= 1'b0;
                end

                if (rxne_flag) owe_flag <= 1'b1; // Overwrite Error
            end
        end else begin
            rxne_flag <= 1'b0;
            {ne_flag, fe_flag, pe_flag, owe_flag} <= 4'd0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_state <= RX_IDLE; rx_parity_bit <= 0; idle_timeout <= 0;
            rx_s_tick_cnt <= 0; temp_ne_flag <= 0; rx_bit_ptr <= 0;
            idle_flag <= 0; rx_shift_reg <= 0; rx_samples <= 0;
        end else if (UE && RE) begin
            if (baud_tick_16x) begin
                case (rx_state)
                    RX_IDLE: begin
                        if (!rx) begin
                            rx_state <= RX_START;
                            rx_s_tick_cnt <= 0;
                            idle_timeout <= 0;
                            idle_flag <= 0;
                            rx_shift_reg <= 0;
                        end else begin
                            if (idle_timeout == 160) idle_flag <= 1'b1;
                            else idle_timeout <= idle_timeout + 1;
                        end
                    end

                    RX_START: begin
                        if (rx_s_tick_cnt == 7 && rx) begin
                            rx_state <= RX_IDLE; // False start glitch
                        end else if (rx_s_tick_cnt == 15) begin
                            rx_s_tick_cnt <= 0;
                            rx_state <= RX_DATA;
                            rx_bit_ptr <= 0;
                            temp_ne_flag <= 0; // Clear intermediate noise flag
                        end else rx_s_tick_cnt <= rx_s_tick_cnt + 1;
                    end

                    RX_DATA: begin
                        if (rx_s_tick_cnt == 7) rx_samples[0] <= rx;
                        if (rx_s_tick_cnt == 8) rx_samples[1] <= rx;
                        if (rx_s_tick_cnt == 9) rx_samples[2] <= rx;

                        if (rx_s_tick_cnt == 15) begin
                            rx_s_tick_cnt <= 0;
                            if (samples_mixed) temp_ne_flag <= 1'b1;
                            rx_shift_reg[rx_bit_ptr] <= decoded_bit;

                            if (rx_bit_ptr == (M ? 4'd8 : 4'd7)) begin
                                rx_state <= PCE ? RX_PARITY : RX_STOP;
                            end else rx_bit_ptr <= rx_bit_ptr + 1;
                        end else rx_s_tick_cnt <= rx_s_tick_cnt + 1;
                    end

                    RX_PARITY: begin
                        if (rx_s_tick_cnt == 7) rx_samples[0] <= rx;
                        if (rx_s_tick_cnt == 8) rx_samples[1] <= rx;
                        if (rx_s_tick_cnt == 9) rx_samples[2] <= rx;

                        if (rx_s_tick_cnt == 15) begin
                            rx_s_tick_cnt <= 0;
                            if (samples_mixed) temp_ne_flag <= 1'b1;
                            rx_parity_bit <= decoded_bit;
                            rx_state <= RX_STOP;
                        end else rx_s_tick_cnt <= rx_s_tick_cnt + 1;
                    end

                    RX_STOP: begin
                        if (rx_s_tick_cnt == 7) rx_samples[0] <= rx;
                        if (rx_s_tick_cnt == 8) rx_samples[1] <= rx;
                        if (rx_s_tick_cnt == 9) rx_samples[2] <= rx;

                        if (rx_s_tick_cnt == 15) begin
                            rx_state <= RX_IDLE;
                            // Data and Status moved synchronously via rx_frame_done
                        end else rx_s_tick_cnt <= rx_s_tick_cnt + 1;
                    end
                endcase
            end
        end else begin
            rx_state <= RX_IDLE;
            rx_s_tick_cnt <= 0;
        end
    end

endmodule
