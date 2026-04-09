`timescale 1ns / 1ps

module fpga_uart_loopback #(
    parameter CLK_FREQ = 50_000_000, // Change to your FPGA's clock frequency
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire reset_btn, // Active-high reset
    input  wire rx,        // Physical RX pin from USB-TTL
    output wire tx         // Physical TX pin to USB-TTL
);

    // Rounded Baud Rate calculation
    localparam [15:0] BRR_VALUE = (CLK_FREQ + (BAUD_RATE * 8)) / (BAUD_RATE * 16);

    // --- Metastability Synchronizer for RX ---
    reg rx_sync1, rx_sync2;
    always @(posedge clk or posedge reset_btn) begin
        if (reset_btn) begin
            rx_sync1 <= 1'b1; // UART idle is High
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // --- UART Core Connections ---
    reg  [15:0] brr_in;  reg brr_en;
    reg  [7:0]  cr_in;   reg cr_en;
    reg  [8:0]  tdr_in;  reg tdr_en;
    reg         rdr_ren;
    wire [7:0]  sr_out;
    wire [8:0]  rdr_out;

    UART_module uart_inst (
        .clk(clk),
        .reset(reset_btn),
        .rx(rx_sync2), // Use the SAFE synchronized RX signal!
        .tx(tx),
        .BRR_in(brr_in), .BRR_en(brr_en),
        .CR_in(cr_in),   .CR_en(cr_en),
        .TDR_in(tdr_in), .TDR_en(tdr_en),
        .RDR_ren(rdr_ren),
        .SR_out(sr_out), .RDR_out(rdr_out)
    );

    // --- Loopback State Machine ---
    localparam S_INIT_BRR = 3'd0,
               S_INIT_CR  = 3'd1,
               S_WAIT_RX  = 3'd2,
               S_READ_RX  = 3'd3,
               S_WAIT_TX  = 3'd4,
               S_SEND_TX  = 3'd5;

    reg [2:0] state = S_INIT_BRR;
    reg [7:0] data_buffer = 8'd0;

    wire rxne_flag = sr_out[1]; // Bit 1 is RX Not Empty
    wire txe_flag  = sr_out[0]; // Bit 0 is TX Empty

    always @(posedge clk or posedge reset_btn) begin
        if (reset_btn) begin
            state <= S_INIT_BRR;
            brr_en <= 0; cr_en <= 0; tdr_en <= 0; rdr_ren <= 0;
            data_buffer <= 0;
        end else begin
            // Default all pulse enables to 0
            brr_en <= 0; cr_en <= 0; tdr_en <= 0; rdr_ren <= 0;

            case (state)
                S_INIT_BRR: begin
                    brr_in <= BRR_VALUE;
                    brr_en <= 1'b1;
                    state  <= S_INIT_CR;
                end
                
                S_INIT_CR: begin
                    // Config: UE=1, TE=1, RE=1, M=0 (8-bit), PCE=0 (No Parity) -> 0x07
                    cr_in <= 8'h07; 
                    cr_en <= 1'b1;
                    state <= S_WAIT_RX;
                end
                
                // 1. Wait for laptop to send a character
                S_WAIT_RX: begin
                    if (rxne_flag == 1'b1) begin
                        state <= S_READ_RX;
                    end
                end
                
                // 2. Latch the data and clear the RXNE flag
                S_READ_RX: begin
                    data_buffer <= rdr_out[7:0]; // Store the received byte
                    rdr_ren <= 1'b1;             // Pulse Read Enable to clear RXNE
                    state <= S_WAIT_TX;
                end
                
                // 3. Wait until the Transmitter is idle
                S_WAIT_TX: begin
                    if (txe_flag == 1'b1) begin
                        state <= S_SEND_TX;
                    end
                end
                
                // 4. Send the exact same byte back to the laptop
                S_SEND_TX: begin
                    tdr_in <= {1'b0, data_buffer};
                    tdr_en <= 1'b1;
                    state  <= S_WAIT_RX; // Go back to waiting for the next keystroke
                end
                
                default: state <= S_INIT_BRR;
            endcase
        end
    end

endmodule