module axi4_apb_bridge #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter ID_WIDTH     = 4,
    parameter N_APB_SLAVES = 4
)(
    input  wire                        ACLK,
    input  wire                        ARESETn,

    // ============================================================
    // AXI4 WRITE ADDRESS CHANNEL
    // ============================================================
    input  wire [ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire                        S_AXI_AWVALID,
    output reg                         S_AXI_AWREADY,
    input  wire [ID_WIDTH-1:0]         S_AXI_AWID,
    input  wire [7:0]                  S_AXI_AWLEN,
    input  wire [2:0]                  S_AXI_AWSIZE,

    // ============================================================
    // AXI4 WRITE DATA CHANNEL
    // ============================================================
    input  wire [DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire                        S_AXI_WVALID,
    output reg                         S_AXI_WREADY,
    input  wire [(DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,

    // ============================================================
    // AXI4 WRITE RESPONSE CHANNEL
    // ============================================================
    output reg  [1:0]                  S_AXI_BRESP,
    output reg                         S_AXI_BVALID,
    input  wire                        S_AXI_BREADY,
    output reg  [ID_WIDTH-1:0]         S_AXI_BID,

    // ============================================================
    // AXI4 READ ADDRESS CHANNEL
    // ============================================================
    input  wire [ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire                        S_AXI_ARVALID,
    output reg                         S_AXI_ARREADY,
    input  wire [ID_WIDTH-1:0]         S_AXI_ARID,
    input  wire [7:0]                  S_AXI_ARLEN,
    input  wire [2:0]                  S_AXI_ARSIZE,

    // ============================================================
    // AXI4 READ DATA CHANNEL
    // ============================================================
    output reg  [DATA_WIDTH-1:0]       S_AXI_RDATA,
    output reg  [1:0]                  S_AXI_RRESP,
    output reg                         S_AXI_RVALID,
    input  wire                        S_AXI_RREADY,
    output reg  [ID_WIDTH-1:0]         S_AXI_RID,
    output reg                         S_AXI_RLAST,

    // ============================================================
    // APB MASTER INTERFACE
    // ============================================================
    output reg  [ADDR_WIDTH-1:0]       PADDR,
    output reg                         PWRITE,
    output reg                         PENABLE,
    output reg  [DATA_WIDTH-1:0]       PWDATA,
    input  wire [DATA_WIDTH-1:0]       PRDATA,
    input  wire                        PREADY,
    input  wire                        PSLVERR,
    output reg  [N_APB_SLAVES-1:0]     PSEL
);

////===============================================================
  //      MY CODE
////===============================================================
    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;

    localparam [3:0] IDLE           = 4'd0,
                     WR_AXI_SETUP   = 4'd1,
                     RD_AXI_SETUP   = 4'd2,
                     WR_APB_SETUP   = 4'd3,
                     RD_APB_SETUP   = 4'd4,
                     WR_APB_ENABLE  = 4'd5,
                     RD_APB_ENABLE  = 4'd6,
                     WR_RESP        = 4'd7,
                     RD_RESP        = 4'd8;

    reg [3:0] state, next_state;

    reg [ADDR_WIDTH-1:0]     awaddr_reg;
    reg [ID_WIDTH-1:0]       awid_reg;
    reg [DATA_WIDTH-1:0]     wdata_reg;
    reg                      write_error;

    reg [ADDR_WIDTH-1:0]     araddr_reg;
    reg [ID_WIDTH-1:0]       arid_reg;
    reg [DATA_WIDTH-1:0]     rdata_reg;
    reg                      read_error;

    // ============================================================
    // NEXT STATE LOGIC
    // ============================================================
    always @(*) begin
        case (state)
            IDLE:          next_state = (S_AXI_AWVALID && S_AXI_WVALID) ? WR_APB_SETUP :
                                        (S_AXI_ARVALID)                  ? RD_APB_SETUP :
                                                                           IDLE;
            WR_APB_SETUP:  next_state = WR_APB_ENABLE;
            RD_APB_SETUP:  next_state = RD_APB_ENABLE;
            WR_APB_ENABLE: next_state = (PREADY) ? WR_RESP : WR_APB_ENABLE;
            RD_APB_ENABLE: next_state = (PREADY) ? RD_RESP : RD_APB_ENABLE;
            WR_RESP:       next_state = (S_AXI_BREADY) ? IDLE : WR_RESP;
            RD_RESP:       next_state = (S_AXI_RREADY) ? IDLE : RD_RESP;
            default:       next_state = IDLE;
        endcase
    end

    // ============================================================
    // STATE / REGISTER SEQUENTIAL BLOCK
    // ============================================================
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            state        <= IDLE;
            awaddr_reg   <= {ADDR_WIDTH{1'b0}};
            awid_reg     <= {ID_WIDTH{1'b0}};
            wdata_reg    <= {DATA_WIDTH{1'b0}};
            write_error  <= 1'b0;
            araddr_reg   <= {ADDR_WIDTH{1'b0}};
            arid_reg     <= {ID_WIDTH{1'b0}};
            rdata_reg    <= {DATA_WIDTH{1'b0}};
            read_error   <= 1'b0;
        end
        else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        awaddr_reg <= S_AXI_AWADDR;
                        awid_reg   <= S_AXI_AWID;
                        wdata_reg  <= S_AXI_WDATA;
                    end
                    else if (S_AXI_ARVALID) begin
                        araddr_reg <= S_AXI_ARADDR;
                        arid_reg   <= S_AXI_ARID;
                    end
                end

                RD_APB_ENABLE: begin
                    if (PREADY)
                        rdata_reg <= PRDATA;
                end
            endcase
        end
    end

    // ============================================================
    // OUTPUT LOGIC
    // ============================================================
    always @(*) begin
        S_AXI_AWREADY = 1'b0;
        S_AXI_WREADY  = 1'b0;
        S_AXI_ARREADY = 1'b0;

        S_AXI_BRESP   = AXI_RESP_OKAY;
        S_AXI_BVALID  = 1'b0;
        S_AXI_BID     = awid_reg;

        S_AXI_RDATA   = rdata_reg;
        S_AXI_RRESP   = AXI_RESP_OKAY;
        S_AXI_RVALID  = 1'b0;
        S_AXI_RID     = arid_reg;
        S_AXI_RLAST   = 1'b1;

        PADDR         = {ADDR_WIDTH{1'b0}};
        PWRITE        = 1'b0;
        PENABLE       = 1'b0;
        PWDATA        = {DATA_WIDTH{1'b0}};
        case (state)
            IDLE: begin
                if (S_AXI_AWVALID && S_AXI_WVALID) begin
                    S_AXI_WREADY  = 1'b1;
                    S_AXI_AWREADY = 1'b1;
                end
                else if (S_AXI_ARVALID) begin
                    S_AXI_ARREADY = 1'b1;
                end
            end

            WR_APB_SETUP: begin
                PADDR   = awaddr_reg;
                PWRITE  = 1'b1;
                PWDATA  = wdata_reg;
            end

            RD_APB_SETUP: begin
                PADDR   = araddr_reg;
                PWRITE  = 1'b0;
            end

            WR_APB_ENABLE: begin
                PADDR   = awaddr_reg;
                PWRITE  = 1'b1;
                PENABLE = 1'b1;
                PWDATA  = wdata_reg;
            end

            RD_APB_ENABLE: begin
                PADDR   = araddr_reg;
                PWRITE  = 1'b0;
                PENABLE = 1'b1;
            end

            WR_RESP: begin
                S_AXI_BVALID = 1'b1;
                S_AXI_BRESP  = (PSLVERR) ? AXI_RESP_SLVERR : AXI_RESP_OKAY;   //write error not used now but must be used later
            end

            RD_RESP: begin
                S_AXI_RVALID = 1'b1;
                S_AXI_RRESP  = (PSLVERR) ? AXI_RESP_SLVERR : AXI_RESP_OKAY;    //read error not used now but must be used later
            end
        endcase
    end

///===================================================================
///  PSEL COMBINATIONAL CODE
///===================================================================
always @(*) begin
    PSEL = 4'b0000;

    case (state)
        WR_APB_SETUP, WR_APB_ENABLE: begin
            if (awaddr_reg >= 32'h0000_2000 && awaddr_reg <= 32'h0000_203F)
                PSEL = 4'b0001;
            else if (awaddr_reg >= 32'h0000_2040 && awaddr_reg <= 32'h0000_207F)
                PSEL = 4'b0010;
            else if (awaddr_reg >= 32'h0000_2080 && awaddr_reg <= 32'h0000_20BF)
                PSEL = 4'b0100;
            else if (awaddr_reg >= 32'h0000_20C0 && awaddr_reg <= 32'h0000_20FF)
                PSEL = 4'b1000;
        end

        RD_APB_SETUP, RD_APB_ENABLE: begin
            if (araddr_reg >= 32'h0000_2000 && araddr_reg <= 32'h0000_203F)
                PSEL = 4'b0001;
            else if (araddr_reg >= 32'h0000_2040 && araddr_reg <= 32'h0000_207F)
                PSEL = 4'b0010;
            else if (araddr_reg >= 32'h0000_2080 && araddr_reg <= 32'h0000_20BF)
                PSEL = 4'b0100;
            else if (araddr_reg >= 32'h0000_20C0 && araddr_reg <= 32'h0000_20FF)
                PSEL = 4'b1000;
        end
    endcase
end
endmodule