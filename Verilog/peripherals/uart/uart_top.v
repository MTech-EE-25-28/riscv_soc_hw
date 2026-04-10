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

    // --- 1. Map APB Writes to UART Inputs ---
    // Relative offset from BASE_ADDR for decoding
    wire [7:0] offset = paddr[7:0] - BASE_ADDR[7:0];

    // --- UART status ---
    wire [7:0] sr_out_wire;
    wire [8:0] rdr_out_wire;

    // transmission complete bit
    wire tc = sr_out_wire[2];

    // --- TDR latch logic (ONLY for offset 0x08) ---
    reg [31:0] latched_pwdata;
    reg        tdr_pending;
    reg        tdr_pending_d;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            latched_pwdata <= 32'b0;
            tdr_pending    <= 1'b0;
            tdr_pending_d  <= 1'b0;
        end else begin
            tdr_pending_d <= tdr_pending;

            // Capture write to TDR (offset 0x08)
            if (apb_write && (offset == 8'h08) && !tdr_pending) begin
                latched_pwdata <= pwdata;
                tdr_pending    <= 1'b1;
            end
            // Clear after enable pulse when tc=1
            else if (tdr_pending_d && tc) begin
                tdr_pending <= 1'b0;
            end
        end
    end

    // Combinational Enables
    wire cr_en_wire  = apb_write && (offset == 8'h0C);
    wire brr_en_wire = apb_write && (offset == 8'h10);

    // Generate ONE-cycle pulse for TDR
    wire tdr_en_wire = tdr_pending && !tdr_pending_d;

    // Data paths
    wire [7:0]  cr_in_wire  = pwdata[7:0];
    wire [15:0] brr_in_wire = pwdata[15:0];
    wire [8:0]  tdr_in_wire = latched_pwdata[8:0];

    // Trigger RDR_ren only when reading the RDR address
    wire rdr_ren_wire = apb_read && (offset == 8'h04);

    // --- 2. APB ready logic ---
    // Stall ONLY for TDR writes until tc=1
    assign pready = (psel && penable) ?
                    ((offset == 8'h08) ? tc : 1'b1)
                    : 1'b0;

    // --- 3. Read / Write decode ---
    always @(*) begin
        prdata = 32'd0;
        pslverr = 1'b0;

        if (apb_read) begin
            case (offset)
                8'h00: prdata = {24'd0, sr_out_wire};
                8'h04: prdata = {23'd0, rdr_out_wire};
                default: pslverr = 1'b1;
            endcase
        end
        else if (apb_write) begin
            case (offset)
                8'h08, 8'h0C, 8'h10: pslverr = 1'b0;
                default: pslverr = 1'b1;
            endcase
        end
    end

    // --- 4. Instantiate the Core UART Module ---
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