// ================================================================
// QSPI CSR - Fully APB3 Compatible
// ================================================================

module qspi_csr #(
    parameter BASE_ADDR = 32'h0000_2000
) (
    input  wire        pclk,
    input  wire        presetn,

    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output reg         pready,
    output wire        pslverr,

    // --- Control outputs ---
    output reg         start,          // 1-cycle pulse
    output reg         enable,
    output reg         quad,
    output reg         cont_read,
    output reg         auto_wren,

    output reg  [7:0]  opcode,
    output reg  [23:0] addr,
    output reg  [15:0] xfer_len,
    output reg  [3:0]  clk_div,

    // TX FIFO Interface
    output reg  [31:0] tx_data_out,
    output reg         tx_wr,
    input  wire        tx_full,
    input  wire        tx_empty,

    // RX FIFO Interface
    input  wire [31:0] rx_data_in,
    output reg         rx_rd,
    input  wire        rx_empty,
    input  wire        rx_full,

    input  wire        done_in
);
    // ------------------------------------------------------------
    // Local Parameters
    // ------------------------------------------------------------
    localparam QSPI_CSR_ADDR    = BASE_ADDR;         // BASE + 0x00
    localparam QSPI_OPCODE_ADDR = BASE_ADDR + 8'h04; // BASE + 0x04
    localparam QSPI_ADDR_ADDR   = BASE_ADDR + 8'h08; // BASE + 0x08
    localparam QSPI_DONE_ADDR   = BASE_ADDR + 8'h0C; // BASE + 0x0C
    localparam QSPI_XLEN_ADDR   = BASE_ADDR + 8'h10; // BASE + 0x10
    localparam QSPI_CLKDIV_ADDR = BASE_ADDR + 8'h14; // BASE + 0x14
    localparam QSPI_TXBUF_STAT = BASE_ADDR + 8'h18;  // BASE + 0x18
    localparam QSPI_RXBUF_STAT = BASE_ADDR + 8'h1C;  // BASE + 0x1C
    localparam QSPI_TXDATA_BUF = BASE_ADDR + 8'h20;  // BASE + 0x20
    localparam QSPI_RXDATA_BUF = BASE_ADDR + 8'h24;  // BASE + 0x24

    // ------------------------------------------------------------
    // Internal registers
    // ------------------------------------------------------------
    reg        done_latch;
    reg [31:0] addr_latched;     // APB address latched in SETUP phase
    reg [31:0] prdata_r;         // read data register

    assign pslverr = 1'b0;       // no error support

    // ------------------------------------------------------------
    // Address latch (SETUP phase)
    // ------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            addr_latched <= 'h00;
        end else if (psel && !penable) begin
            addr_latched <= paddr;   // latch address only in SETUP phase
        end
    end

    // ------------------------------------------------------------
    // Done latch
    // ------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn)
            done_latch <= 1'b0;
        else if (done_in)
            done_latch <= 1'b1;
        else if (psel && penable && pwrite && addr_latched == 8'h0C)
            done_latch <= 1'b0;    // explicit clear on write
    end

    // ------------------------------------------------------------
    // APB WRITE: occurs in ACCESS phase (psel=1, penable=1, pwrite=1)
    // ------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin

            enable     <= 0;
            quad       <= 0;
            cont_read  <= 0;
            auto_wren  <= 0;

            opcode     <= 0;
            addr       <= 0;
            xfer_len   <= 0;
            clk_div    <= 4'd1;

            tx_data_out <= 0;

            start      <= 0;
            tx_wr      <= 0;
            rx_rd      <= 0;

        end else begin

            // defaults
            start <= 0;
            tx_wr <= 0;
            rx_rd <= 0;

            if (psel && penable && pwrite) begin
                case (addr_latched)

                    QSPI_CSR_ADDR: begin
                        enable     <= pwdata[0];
                        quad       <= pwdata[1];
                        cont_read  <= pwdata[2];
                        auto_wren  <= pwdata[3];
                        clk_div    <= pwdata[7:4];
                        if (pwdata[8])
                            start <= 1'b1;   // 1-cycle pulse
                    end

                    QSPI_OPCODE_ADDR: opcode   <= pwdata[7:0];
                    QSPI_ADDR_ADDR  : addr     <= pwdata[23:0];
                    QSPI_XLEN_ADDR  : xfer_len <= pwdata[15:0];

                    QSPI_TXDATA_BUF: begin
                        if (!tx_full) begin
                            tx_data_out <= pwdata;
                            tx_wr       <= 1'b1;
                        end
                    end

                    QSPI_RXDATA_BUF: begin
                        if (!rx_empty)
                            rx_rd <= 1'b1;
                    end

                endcase
            end
        end
    end

    // ------------------------------------------------------------
    // APB READ: register mux
    // (Used during ACCESS phase for psel=1, penable=1, pwrite=0)
    // ------------------------------------------------------------
    always @(*) begin
        case (addr_latched)

            QSPI_CSR_ADDR   : prdata_r = {23'd0, clk_div, auto_wren, cont_read, quad, enable};
            QSPI_OPCODE_ADDR: prdata_r = {24'd0, opcode};
            QSPI_ADDR_ADDR  : prdata_r = {8'd0, addr};

            QSPI_DONE_ADDR  : prdata_r = {31'd0, done_latch};

            QSPI_XLEN_ADDR  : prdata_r = {16'd0, xfer_len};
            QSPI_CLKDIV_ADDR: prdata_r = {28'd0, clk_div};

            QSPI_TXBUF_STAT : prdata_r = {30'd0, tx_empty, tx_full};
            QSPI_RXBUF_STAT : prdata_r = {30'd0, rx_empty, rx_full};

            QSPI_TXDATA_BUF : prdata_r = tx_data_out;
            QSPI_RXDATA_BUF : prdata_r = rx_data_in;

            default: prdata_r = 32'd0;
        endcase
    end

    // ------------------------------------------------------------
    // PRDATA and PREADY generation
    // ------------------------------------------------------------
    assign prdata =
        (psel && penable && !pwrite) ? prdata_r : 32'd0;

    always @(*) begin
        // zero-wait-state slave
        if (psel && penable)
            pready = 1'b1;
        else
            pready = 1'b0;
    end

endmodule