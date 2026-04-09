
module uart_top #(
    parameter BASE_ADDR = 32'h0000_2040
) (
    // APB Bus Interface
    input  wire        pclk,
    input  wire        presetn,  // APB reset is active-low
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output reg         pslverr,

    // UART Physical Interface
    input  wire        rx,
    output wire        tx
);

    // APB Transaction Phase Detectors
    wire apb_access = psel && penable;
    wire apb_write  = apb_access && pwrite;
    wire apb_read   = apb_access && !pwrite;

    // Assert pready only in APB access phase (psel && penable), matching timer/gpio pattern.
    // If pready=1 unconditionally the FSM sees pready before penable is ever asserted,
    // overrides penable back to 0, and the slave never sees apb_write=1.
    assign pready = (psel && penable) ? 1'b1 : 1'b0;

    // --- 1. Map APB Writes to UART Inputs ---
    // Relative offset from BASE_ADDR for decoding
    wire [7:0] offset = paddr[7:0] - BASE_ADDR[7:0];

    // Combinational Enables: These pulse High only during the APB Access Phase
    wire cr_en_wire  = apb_write && (offset == 8'h0C);
    wire brr_en_wire = apb_write && (offset == 8'h10);
    wire tdr_en_wire = apb_write && (offset == 8'h08);

    // Data passes directly from the APB bus to the UART inputs.
    // The UART will only latch them when the respective _en wire is high.
    wire [7:0]  cr_in_wire  = pwdata[7:0];
    wire [15:0] brr_in_wire = pwdata[15:0];
    wire [8:0]  tdr_in_wire = pwdata[8:0];

    // --- 2. Map APB Reads to UART Outputs ---
    wire [7:0] sr_out_wire;
    wire [8:0] rdr_out_wire;

    // Trigger RDR_ren only when reading the RDR address
    wire rdr_ren_wire = apb_read && (offset == 8'h04);

    always @(*) begin
        prdata = 32'd0;
        pslverr = 1'b0;

        if (apb_read) begin
            case (offset)
                8'h00: prdata = {24'd0, sr_out_wire};  // Pad upper bits with 0
                8'h04: prdata = {23'd0, rdr_out_wire}; // Pad upper bits with 0
                default: pslverr = 1'b1; // Invalid read address
            endcase
        end
        else if (apb_write) begin
            case (offset)
                8'h08, 8'h0C, 8'h10: pslverr = 1'b0; // Valid write addresses
                default: pslverr = 1'b1;             // Invalid write address
            endcase
        end
    end

    // --- 3. Instantiate the Core UART Module ---
    // Convert active-low APB reset to active-high UART reset
    wire uart_reset = ~presetn;

    UART_module core_uart (
        .clk(pclk),
        .reset(uart_reset),

        .rx(rx),
        .tx(tx),

        .CR_in(cr_in_wire),
        .CR_en(cr_en_wire),

        .BRR_in(brr_in_wire),
        .BRR_en(brr_en_wire),

        .TDR_in(tdr_in_wire),
        .TDR_en(tdr_en_wire),

        .RDR_ren(rdr_ren_wire),

        .SR_out(sr_out_wire),
        .RDR_out(rdr_out_wire)
    );

endmodule