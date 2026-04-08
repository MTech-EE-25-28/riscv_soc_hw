`timescale 1ns/1ps

module tb_axi4_apb_bridge;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter ID_WIDTH   = 4;

    reg ACLK;
    reg ARESETn;

    // AXI WRITE
    reg [ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg S_AXI_AWVALID;
    wire S_AXI_AWREADY;
    reg [ID_WIDTH-1:0] S_AXI_AWID;

    reg [DATA_WIDTH-1:0] S_AXI_WDATA;
    reg S_AXI_WVALID;
    wire S_AXI_WREADY;

    wire [1:0] S_AXI_BRESP;
    wire S_AXI_BVALID;
    reg S_AXI_BREADY;
    wire [ID_WIDTH-1:0] S_AXI_BID;

    // AXI READ
    reg [ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg S_AXI_ARVALID;
    wire S_AXI_ARREADY;
    reg [ID_WIDTH-1:0] S_AXI_ARID;

    wire [DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0] S_AXI_RRESP;
    wire S_AXI_RVALID;
    reg S_AXI_RREADY;
    wire [ID_WIDTH-1:0] S_AXI_RID;

    // APB
    wire [ADDR_WIDTH-1:0] PADDR;
    wire PWRITE;
    wire PENABLE;
    wire [DATA_WIDTH-1:0] PWDATA;
    reg  [DATA_WIDTH-1:0] PRDATA;
    reg  PREADY;
    reg  PSLVERR;
    wire [3:0] PSEL;

    // DUT
    axi4_apb_bridge dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_AWID(S_AXI_AWID),

        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),

        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_BID(S_AXI_BID),

        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_ARID(S_AXI_ARID),

        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),
        .S_AXI_RID(S_AXI_RID),

        .PADDR(PADDR),
        .PWRITE(PWRITE),
        .PENABLE(PENABLE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),
        .PSEL(PSEL)
    );

    // Clock
    always #5 ACLK = ~ACLK;

    // ============================================================
    // APB SLAVE MODEL (simple)
    // ============================================================
    always @(posedge ACLK) begin
        if (PENABLE) begin
            PREADY <= 1;
            if (!PWRITE) begin
                PRDATA <= 32'hABCD_1234; // fixed read data
            end
        end else begin
            PREADY <= 0;
        end
    end

    // ============================================================
    // TEST SEQUENCE
    // ============================================================
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_axi4_apb_bridge);

        // init
        ACLK = 0;
        ARESETn = 0;

        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_BREADY  = 0;

        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;

        PREADY = 0;
        PSLVERR = 0;
        PRDATA = 0;

        #20;
        ARESETn = 1;

        // ========================================================
        // WRITE TRANSACTION
        // ========================================================
        @(posedge ACLK);
        S_AXI_AWADDR  = 32'h0000_2004;
        S_AXI_AWVALID = 1;
        S_AXI_WDATA   = 32'hDEADBEEF;
        S_AXI_WVALID  = 1;
        S_AXI_BREADY  = 1;

        wait (S_AXI_AWREADY && S_AXI_WREADY);
        @(posedge ACLK);
        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;

        wait (S_AXI_BVALID);
        $display("WRITE DONE: BRESP=%0d", S_AXI_BRESP);
        @(posedge ACLK);

        // ========================================================
        // READ TRANSACTION
        // ========================================================
        @(posedge ACLK);
        S_AXI_ARADDR  = 32'h0000_2004;
        S_AXI_ARVALID = 1;
        S_AXI_RREADY  = 1;

        wait (S_AXI_ARREADY);
        @(posedge ACLK);
        S_AXI_ARVALID = 0;

        wait (S_AXI_RVALID);
        $display("READ DONE: DATA=0x%h", S_AXI_RDATA);

        #20;
        $finish;
    end

    // ============================================================
    // DEBUG PRINTS
    // ============================================================
    always @(posedge ACLK) begin
        $display("T=%0t | PSEL=%b PADDR=%h PWRITE=%b PENABLE=%b PWDATA=%h",
                 $time, PSEL, PADDR, PWRITE, PENABLE, PWDATA);
    end

endmodule