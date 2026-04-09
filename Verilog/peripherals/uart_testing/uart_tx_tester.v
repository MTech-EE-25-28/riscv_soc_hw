`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.04.2026 03:23:34
// Design Name: 
// Module Name: fpga_uart_tx_tester
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

module fpga_uart_tx_tester #(
    parameter CLK_FREQ = 50_000_000, // Change to your FPGA's clock frequency
    parameter BAUD_RATE = 115200     // Target Baud Rate
)(
    input  wire clk,
    input  wire reset_btn, // Assume active-high reset button
    input  wire rx,        // Physical RX pin
    output wire tx         // Physical TX pin
);

    // Calculate BRR divisor automatically
    localparam [15:0] BRR_VALUE = CLK_FREQ / (BAUD_RATE * 16);

    // --- UART Core Connections ---
    reg  [15:0] brr_in;
    reg         brr_en;
    reg  [7:0]  cr_in;
    reg         cr_en;
    reg  [8:0]  tdr_in;
    reg         tdr_en;
    reg         rdr_ren;
    wire [7:0]  sr_out;
    wire [8:0]  rdr_out;

    UART_module uart_inst (
        .clk(clk),
        .reset(reset_btn),
        .rx(rx),
        .tx(tx),
        .BRR_in(brr_in),
        .BRR_en(brr_en),
        .CR_in(cr_in),
        .CR_en(cr_en),
        .TDR_in(tdr_in),
        .TDR_en(tdr_en),
        .RDR_ren(rdr_ren),
        .SR_out(sr_out),
        .RDR_out(rdr_out)
    );

    // --- State Machine ---
    localparam S_INIT_BRR = 3'd0,
               S_INIT_CR  = 3'd1,
               S_WAIT_TXE = 3'd2,
               S_SEND     = 3'd3,
               S_DELAY    = 3'd4;

    reg [2:0] state = S_INIT_BRR;
    reg [7:0] char_to_send = 8'h61; // Start at 'a'
    reg [23:0] delay_cnt = 0;       // Delay counter for readability

    wire txe_flag = sr_out[0];

    always @(posedge clk or posedge reset_btn) begin
        if (reset_btn) begin
            state <= S_INIT_BRR;
            brr_en <= 0;
            cr_en <= 0;
            tdr_en <= 0;
            rdr_ren <= 0;
            char_to_send <= 8'h61; // 'a'
            delay_cnt <= 0;
        end else begin
            // Default all enables to 0 (pulse generation)
            brr_en <= 0;
            cr_en <= 0;
            tdr_en <= 0;

            case (state)
                S_INIT_BRR: begin
                    brr_in <= BRR_VALUE;
                    brr_en <= 1'b1;
                    state <= S_INIT_CR;
                end
                
                S_INIT_CR: begin
                    // Config: UE=1, TE=1, RE=0, M=0 (8-bit), PCE=0 (No Parity)
                    cr_in <= 8'h03; 
                    cr_en <= 1'b1;
                    state <= S_WAIT_TXE;
                end
                
                S_WAIT_TXE: begin
                    if (txe_flag == 1'b1) begin
                        state <= S_SEND;
                    end
                end
                
                S_SEND: begin
                    tdr_in <= {1'b0, char_to_send};
                    tdr_en <= 1'b1;
                    
                    // Logic to loop 'a' to 'z', then send \r and \n
                    if (char_to_send == 8'h7A) char_to_send <= 8'h0D;      // 'z' -> '\r'
                    else if (char_to_send == 8'h0D) char_to_send <= 8'h0A; // '\r' -> '\n'
                    else if (char_to_send == 8'h0A) char_to_send <= 8'h61; // '\n' -> 'a'
                    else char_to_send <= char_to_send + 1;
                    
                    state <= S_DELAY;
                end
                
                S_DELAY: begin
                    // Wait ~0.1 seconds at 50MHz so you can watch it print
                    if (delay_cnt >= 5_000_000) begin 
                        delay_cnt <= 0;
                        state <= S_WAIT_TXE;
                    end else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end
                
                default: state <= S_INIT_BRR;
            endcase
        end
    end

endmodule
