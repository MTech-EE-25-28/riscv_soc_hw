`timescale 1ns / 1ps

module fpga_apb_uart_tester #(
    parameter CLK_FREQ = 50_000_000, // Update to match your FPGA oscillator
    parameter BAUD_RATE = 115200,
    parameter BASE_ADDR = 32'h0000_2040
)(
    input  wire clk,
    input  wire reset_btn, // Assumes active-high reset button
    input  wire rx,
    output wire tx
);

    // Rounded Baud Rate calculation to prevent integer truncation drift
    localparam [15:0] BRR_VALUE = (CLK_FREQ + (BAUD_RATE * 8)) / (BAUD_RATE * 16);

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

    // --- Instantiate the UART APB Wrapper ---
    uart_top #(
        .BASE_ADDR(BASE_ADDR)
    ) uart_inst (
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
        .rx(rx),
        .tx(tx)
    );

    // --- Register Addresses ---
    localparam ADDR_SR  = BASE_ADDR + 8'h00;
    localparam ADDR_TDR = BASE_ADDR + 8'h08;
    localparam ADDR_CR1 = BASE_ADDR + 8'h0C;
    localparam ADDR_BRR = BASE_ADDR + 8'h10;

    // --- Hardware APB Master State Machine ---
    reg [3:0]  state;
    reg [7:0]  char_reg;
    reg [23:0] delay_cnt;

    always @(posedge clk) begin
        if (reset_btn) begin
            presetn <= 0; // Assert APB reset (Active Low)
            psel <= 0;
            penable <= 0;
            pwrite <= 0;
            state <= 0;
            char_reg <= 8'h41; // Start at 'A'
            delay_cnt <= 0;
        end else begin
            presetn <= 1; // Release APB reset

            case (state)
                // ---------------------------------------------------
                // Step 1: Initialize BRR
                // ---------------------------------------------------
                0: begin 
                    psel <= 1; pwrite <= 1; paddr <= ADDR_BRR; pwdata <= BRR_VALUE; 
                    penable <= 0; // Setup Phase
                    state <= 1; 
                end
                1: begin 
                    penable <= 1; // Access Phase
                    if (pready) state <= 2; 
                end
                2: begin 
                    psel <= 0; penable <= 0; // Cleanup
                    state <= 3; 
                end

                // ---------------------------------------------------
                // Step 2: Initialize CR1 (UE=1, TE=1, RE=0, 8-bit, No Parity)
                // ---------------------------------------------------
                3: begin 
                    psel <= 1; pwrite <= 1; paddr <= ADDR_CR1; pwdata <= 32'h03; 
                    penable <= 0; 
                    state <= 4; 
                end
                4: begin 
                    penable <= 1; 
                    if (pready) state <= 5; 
                end
                5: begin 
                    psel <= 0; penable <= 0; 
                    state <= 6; 
                end

                // ---------------------------------------------------
                // Step 3: Poll SR to check if TXE is 1
                // ---------------------------------------------------
                6: begin 
                    psel <= 1; pwrite <= 0; paddr <= ADDR_SR; 
                    penable <= 0; 
                    state <= 7; 
                end
                7: begin 
                    penable <= 1; 
                    if (pready) state <= 8; 
                end
                8: begin
                    psel <= 0; penable <= 0;
                    if (prdata[0] == 1'b1) state <= 9; // TXE == 1, ready to send
                    else state <= 6;                   // Keep polling SR
                end

                // ---------------------------------------------------
                // Step 4: Write character to TDR
                // ---------------------------------------------------
                9:  begin 
                    psel <= 1; pwrite <= 1; paddr <= ADDR_TDR; pwdata <= {24'd0, char_reg}; 
                    penable <= 0; 
                    state <= 10; 
                end
                10: begin 
                    penable <= 1; 
                    if (pready) state <= 11; 
                end
                11: begin
                    psel <= 0; penable <= 0;
                    
                    // Sequence Logic: 'A'-'Z' -> '1'-'9' -> 'a'-'z' -> '\r\n'
                    if      (char_reg == 8'h5A) char_reg <= 8'h31; // 'Z' -> '1'
                    else if (char_reg == 8'h39) char_reg <= 8'h61; // '9' -> 'a'
                    else if (char_reg == 8'h7A) char_reg <= 8'h0D; // 'z' -> '\r'
                    else if (char_reg == 8'h0D) char_reg <= 8'h0A; // '\r' -> '\n'
                    else if (char_reg == 8'h0A) char_reg <= 8'h41; // '\n' -> 'A'
                    else char_reg <= char_reg + 1;
                    
                    state <= 12;
                end

                // ---------------------------------------------------
                // Step 5: Delay between characters (for human readability)
                // ---------------------------------------------------
                12: begin
                    if (delay_cnt >= (CLK_FREQ / 10)) begin // ~100ms delay
                        delay_cnt <= 0;
                        state <= 6; // Go back to polling SR for the next character
                    end else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end

                default: state <= 0;
            endcase
        end
    end
endmodule