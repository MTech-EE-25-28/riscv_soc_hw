module qspi_top (
    input  wire        clk,
    input  wire        resetn,

    // -----------------------------
    // APB Interface
    // -----------------------------
    input  wire        pclk,
    input  wire        presetn,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [7:0]  paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // -----------------------------
    // QSPI IOs
    // -----------------------------
    inout  wire [3:0]  io,
    output wire        sck,
    output wire        cs_n,

    // Interrupt
    output wire        irq_done
);

    // ==========================================================
    // CSR ? FSM
    // ==========================================================
    wire        csr_start;
    wire        csr_enable;
    wire        csr_quad;
    wire        csr_cont_read;
    wire        csr_auto_wren;

    wire [7:0]  csr_opcode;
    wire [23:0] csr_addr;
    wire [15:0] csr_xfer_len;
    wire [3:0]  csr_clk_div;

    // ==========================================================
    // CSR ? TX FIFO
    // ==========================================================
    wire [31:0]  csr_tx_data;
    wire        csr_tx_wr;
    wire        tx_full;
    wire        tx_empty;

    // ==========================================================
    // CSR ? RX FIFO
    // ==========================================================
    wire [31:0]  csr_rx_data;
    wire        csr_rx_rd;
    wire        rx_empty;
    wire        rx_full;

    // ==========================================================
    // FSM ? TX FIFO
    // ==========================================================
    wire        txfifo_rd;
    wire [7:0]  txfifo_rdata;

    // ==========================================================
    // FSM ? RX FIFO
    // ==========================================================
    wire        rxfifo_wr;
    wire [7:0]  rxfifo_wdata;

    // ==========================================================
    // FSM ? Shifter (NEW INTERFACE)
    // ==========================================================
    wire        fsm_load_chunk;
    wire [31:0] fsm_chunk_data;
    wire [5:0]  fsm_chunk_cycles;

    wire        shifter_start;
    wire        shifter_dir;

    wire        shifter_done;
    wire        shifter_data_req;
    wire        shifter_data_ready;
    wire [7:0]  shifter_rdata;

    // ==========================================================
    // FSM status
    // ==========================================================
    wire tx_done;
    wire rx_done;
    wire shifter_busy;
    wire fsm_quad;

    // ==========================================================
    // Clock edges
    // ==========================================================
    wire sck_rise, sck_fall;

    // ==========================================================
    // CSR
    // ==========================================================
    qspi_csr csr_i (
        .pclk(pclk),
        .presetn(presetn),

        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),

        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),

        .start(csr_start),
        .enable(csr_enable),
        .quad(csr_quad),
        .cont_read(csr_cont_read),
        .auto_wren(csr_auto_wren),

        .opcode(csr_opcode),
        .addr(csr_addr),
        .xfer_len(csr_xfer_len),
        .clk_div(csr_clk_div),

        .tx_data_out(csr_tx_data),
        .tx_wr(csr_tx_wr),
        .tx_full(tx_full),
        .tx_empty(tx_empty),

        .rx_data_in(csr_rx_data),
        .rx_rd(csr_rx_rd),
        .rx_empty(rx_empty),
        .rx_full(rx_full),

        .done_in(irq_done)
    );

    // ==========================================================
    // TX FIFO
    // ==========================================================
    fifo_sync1 #(.DATA_WIDTH(8), .DEPTH(32)) tx_fifo (
        .clk(clk),
        .resetn(resetn),

        .wr_en(csr_tx_wr),
        .wr_data(csr_tx_data),
        .full(tx_full),

        .rd_en(txfifo_rd),
        .rd_data(txfifo_rdata),
        .empty(tx_empty)
    );

    // ==========================================================
    // RX FIFO
    // ==========================================================
    fifo_sync2 #(.DATA_WIDTH(8), .DEPTH(32)) rx_fifo (
        .clk(clk),
        .resetn(resetn),

        .wr_en(rxfifo_wr),
        .wr_data(rxfifo_wdata),
        .full(rx_full),

        .rd_en(csr_rx_rd),
        .rd_data(csr_rx_data),
        .empty(rx_empty)
    );

    // ==========================================================
    // Clock Generator
    // ==========================================================
    qspi_clk_gen clkgen_i (
        .clk(clk),
        .resetn(resetn),
        .enable(shifter_busy),
        .clk_div(csr_clk_div),

        .sck(sck),
        .sck_rise(sck_rise),
        .sck_fall(sck_fall)
    );

    // ==========================================================
    // FSM (NEW)
    // ==========================================================
    qspi_cmd_fsm u_fsm (
        .clk(clk),
        .resetn(resetn),

        .start(csr_start),


        .csr_opcode(csr_opcode),
        .csr_addr(csr_addr),
        .csr_length(csr_xfer_len),

        .txfifo_empty(tx_empty),
        .txfifo_rd(txfifo_rd),
        .txfifo_rdata(txfifo_rdata),

        .rxfifo_full(rx_full),
        .rxfifo_wr(rxfifo_wr),
        .rxfifo_wdata(rxfifo_wdata),

        // NEW chunk interface (internal in FSM)
        .load_chunk(fsm_load_chunk),
        .chunk_data(fsm_chunk_data),
        .chunk_cycles(fsm_chunk_cycles),

        .shifter_dir(shifter_dir),
        .shifter_busy(shifter_busy),
        .shifter_done(shifter_done),
        .shifter_data_req(shifter_data_req),
        .shifter_data_ready(shifter_data_ready),
        .shifter_rxbyte(shifter_rdata),
        .fsm_quad(fsm_quad),

        .cs_n(cs_n),          // NEW: CS controlled by FSM
        .busy(),
        .done (irq_done)
    );

    // ==========================================================
    // Shifter
    // ==========================================================
    qspi_shift shifter_i (
        .clk(clk),
        .resetn(resetn),

        .dir_rx(shifter_dir),

        .quad_tx(fsm_quad),
        .quad_rx(fsm_quad),

        .load_chunk(fsm_load_chunk),
        .chunk_data(fsm_chunk_data),
        .chunk_cycles(fsm_chunk_cycles),

        .sck_rise(sck_rise),
        .sck_fall(sck_fall),

        .io(io),

        .data_req(shifter_data_req),

        .rx_byte(shifter_rdata),
        .data_ready(shifter_data_ready),

        .busy(shifter_busy),
        .done(shifter_done)
    );

endmodule