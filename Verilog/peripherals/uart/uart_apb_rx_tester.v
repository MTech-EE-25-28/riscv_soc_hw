`timescale 1ns / 1ps

module fpga_apb_loopback #(
    parameter CLK_FREQ = 50_000_000, 
    parameter BAUD_RATE = 115200,
    parameter BASE_ADDR = 32'h0000_2040
)(
    input  wire clk,
    input  wire reset_btn, // Active-high reset
    input  wire rx,
    output wire tx
);

    // Rounded Baud Rate calculation
    localparam [15:0] BRR_VALUE = (CLK_FREQ + (BAUD_RATE * 8)) / (BAUD_RATE * 16);

    // --- Metastability Synchronizer for RX ---
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

    // --- APB Bus Signals ---
    reg         presetn;
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [31:0] paddr;
    reg  [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready;
    wire        pslverr;

    uart_top #(.BASE_ADDR(BASE_ADDR)) uart_inst (
        .pclk(clk),
        .presetn(presetn),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        .rx(rx_sync2),
        .tx(tx)
    );

    // Register Offsets
    localparam ADDR_SR  = BASE_ADDR + 8'h00;
    localparam ADDR_RDR = BASE_ADDR + 8'h04;
    localparam ADDR_TDR = BASE_ADDR + 8'h08;
    localparam ADDR_CR1 = BASE_ADDR + 8'h0C;
    localparam ADDR_BRR = BASE_ADDR + 8'h10;

    // --- State Machine ---
    reg [3:0] state;
    reg [7:0] data_buffer;

    always @(posedge clk) begin
        if (reset_btn) begin
            presetn <= 0; psel <= 0; penable <= 0; pwrite <= 0;
            state <= 0; data_buffer <= 0;
        end else begin
            presetn <= 1;
            case (state)
                // 1. Init BRR
                0: begin psel <= 1; pwrite <= 1; paddr <= ADDR_BRR; pwdata <= BRR_VALUE; penable <= 0; state <= 1; end
                1: begin penable <= 1; if (pready) state <= 2; end
                2: begin psel <= 0; penable <= 0; state <= 3; end

                // 2. Init CR1 (UE=1, TE=1, RE=1) -> 0x07
                3: begin psel <= 1; pwrite <= 1; paddr <= ADDR_CR1; pwdata <= 32'h07; penable <= 0; state <= 4; end
                4: begin penable <= 1; if (pready) state <= 5; end
                5: begin psel <= 0; penable <= 0; state <= 6; end

                // 3. Poll SR for RXNE (Bit 1)
                6: begin psel <= 1; pwrite <= 0; paddr <= ADDR_SR; penable <= 0; state <= 7; end
                7: begin penable <= 1; if (pready) state <= 8; end
                8: begin
                    psel <= 0; penable <= 0;
                    if (prdata[1]) state <= 9; // RXNE is set
                    else state <= 6;           // Keep polling
                end

                // 4. Read RDR (This automatically clears RXNE in your wrapper)
                9:  begin psel <= 1; pwrite <= 0; paddr <= ADDR_RDR; penable <= 0; state <= 10; end
                10: begin penable <= 1; if (pready) begin data_buffer <= prdata[7:0]; state <= 11; end end
                11: begin psel <= 0; penable <= 0; state <= 12; end

                // 5. Poll SR for TXE (Bit 0)
                12: begin psel <= 1; pwrite <= 0; paddr <= ADDR_SR; penable <= 0; state <= 13; end
                13: begin penable <= 1; if (pready) state <= 14; end
                14: begin
                    psel <= 0; penable <= 0;
                    if (prdata[0]) state <= 15; // TXE is set
                    else state <= 12;
                end

                // 6. Write Data back to TDR
                15: begin psel <= 1; pwrite <= 1; paddr <= ADDR_TDR; pwdata <= {24'd0, data_buffer}; penable <= 0; state <= 16; end
                16: begin penable <= 1; if (pready) state <= 17; end
                17: begin psel <= 0; penable <= 0; state <= 6; end // Return to polling RX

                default: state <= 0;
            endcase
        end
    end
endmodule