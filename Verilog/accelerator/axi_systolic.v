`timescale 1ns / 1ps

module axi_systolic_ctrl (

    input wire ACLK,
    input wire ARESETN,
    // input job,

    // READ ADDRESS
    input wire ARVALID,
    output reg ARREADY,
    input wire [31:0] ARADDR,
    input wire [7:0] ARLEN,

    // READ DATA
    output reg RVALID,
    input wire RREADY,
    output reg RLAST,
    output reg [31:0] RDATA,
    output reg [1:0] RRESP,

    // WRITE ADDRESS
    input wire AWVALID,
    output reg AWREADY,
    input wire [31:0] AWADDR,
    input wire [7:0] AWLEN,

    // WRITE DATA
    input wire WVALID,
    output reg WREADY,
    input wire WLAST,
    input wire [31:0] WDATA,

    // WRITE RESPONSE
    output reg BVALID,
    input wire BREADY,
    output reg [1:0] BRESP
);

//////////////////// ADDRESS MAP ////////////////////
localparam BASE_ADDR = 32'h00020000;

localparam CTRL_ADDR = BASE_ADDR + 32'h00;

localparam A_BASE    = BASE_ADDR + 32'h10; // 0x00020010
localparam B_BASE    = BASE_ADDR + 32'h50; // 0x00020050
localparam C_BASE    = BASE_ADDR + 32'h90; // 0x00020090

//////////////////// CONTROL ////////////////////
reg start, busy, irq_en, irq_status;

//////////////////// MEMORY ////////////////////
reg [31:0] A_mem [0:15];
reg [31:0] B_mem [0:15];
reg [31:0] C_mem [0:31];

//////////////////// SYSTOLIC ////////////////////
reg [31:0] A1, A2, A3, A4;
reg [31:0] B1, B2, B3, B4;

wire [63:0] C11, C12, C13, C14;
wire [63:0] C21, C22, C23, C24;
wire [63:0] C31, C32, C33, C34;
wire [63:0] C41, C42, C43, C44;

systolic_4x4 systolic_inst (
    .clk(ACLK),
    .reset(ARESETN),        // ARESETN=1 resets DUT; systolic PE is active-HIGH reset

    

    .A1(A1), .A2(A2), .A3(A3), .A4(A4),
    .B1(B1), .B2(B2), .B3(B3), .B4(B4),

    .C11(C11), .C12(C12), .C13(C13), .C14(C14),
    .C21(C21), .C22(C22), .C23(C23), .C24(C24),
    .C31(C31), .C32(C32), .C33(C33), .C34(C34),
    .C41(C41), .C42(C42), .C43(C43), .C44(C44)
);

//////////////////// FSM ////////////////////

// WRITE FSM
reg [1:0] wstate;
reg [31:0] waddr;
reg [7:0] wlen_cnt;
reg aw_latched;                          // tracks if AWADDR has been latched
localparam W_IDLE=0, W_DATA=1, W_RESP=2, W_RESP_N=3;

// READ FSM
reg [1:0] rstate;
reg [31:0] raddr;
reg [7:0] rlen_cnt;
localparam R_IDLE=0, R_DATA=1, R_RESP_N=2;

// CONTROL FSM
reg [1:0] cstate;
reg [3:0] cycle_cnt;
localparam S_IDLE=0, S_BUSY=1, S_WRITE=2, S_DONE=3;

//////////////////// CONTROL FSM ////////////////////
always @(posedge ACLK) begin
    if (ARESETN) begin
        busy       <= 0;
        irq_status <= 0;
        irq_en     <= 0;
        cycle_cnt  <= 0;
        A1 <= 0; A2 <= 0; A3 <= 0; A4 <= 0;
        B1 <= 0; B2 <= 0; B3 <= 0; B4 <= 0;
        start <= 0;

        cstate     <= S_IDLE;
    end else begin
        case(cstate)

        S_IDLE: begin
            busy <= 0;
            irq_en <= 0;
            if (start) begin
                cycle_cnt <= 0;
                cstate <= S_BUSY;
            end
        end

          S_BUSY: begin
            busy <= 1;
            cycle_cnt <= cycle_cnt + 1;
            case(cycle_cnt)
            // Cycle 0
            0: begin
                A1<=A_mem[0]; A2<=0; A3<=0; A4<=0;
                B1<=B_mem[0]; B2<=0; B3<=0; B4<=0;
            end
            // Cycle 1
            1: begin
                A1<=A_mem[1]; A2<=A_mem[4]; A3<=0; A4<=0;
                B1<=B_mem[4]; B2<=B_mem[1]; B3<=0; B4<=0;
            end
            // Cycle 2
            2: begin
                A1<=A_mem[2]; A2<=A_mem[5];  A3<=A_mem[8];  A4<=0;
                B1<=B_mem[8]; B2<=B_mem[5];  B3<=B_mem[2];  B4<=0;
            end
            // Cycle 3
            3: begin
                A1<=A_mem[3]; A2<=A_mem[6];  A3<=A_mem[9];  A4<=A_mem[12];
                B1<=B_mem[12];B2<=B_mem[9];  B3<=B_mem[6];  B4<=B_mem[3];
            end
            // Cycle 4
            4: begin
                A1<=0; A2<=A_mem[7];  A3<=A_mem[10]; A4<=A_mem[13];
                B1<=0; B2<=B_mem[13]; B3<=B_mem[10]; B4<=B_mem[7];
            end
            // Cycle 5
            5: begin
                A1<=0; A2<=0; A3<=A_mem[11]; A4<=A_mem[14];
                B1<=0; B2<=0; B3<=B_mem[14]; B4<=B_mem[11];
            end
            // Cycle 6
            6: begin
                A1<=0; A2<=0; A3<=0; A4<=A_mem[15];
                B1<=0; B2<=0; B3<=0; B4<=B_mem[15];
            end
            // Flush cycles
            default: begin
                A1<=0; A2<=0; A3<=0; A4<=0;
                B1<=0; B2<=0; B3<=0; B4<=0;
            end
            endcase
            // Total cycles = 7 (fill) + ~4 (compute flush)
            if (cycle_cnt == 12) begin
                cycle_cnt <= 0;
                cstate <= S_WRITE;
            end
        end 
        //        S_BUSY: begin
        //            busy <= 1;

//            // Feed systolic array inputs (only col-0 of A, row-0 of B)
//            A1 <= A_mem[0];
//            A2 <= A_mem[4];
//            A3 <= A_mem[8];
//            A4 <= A_mem[12];

//            B1 <= B_mem[0];
//            B2 <= B_mem[1];
//            B3 <= B_mem[2];
//            B4 <= B_mem[3];

//            cstate <= S_WRITE;
//        end

        S_WRITE: begin
            // Capture all 16 x 64-bit results into C_mem (two 32-bit words each)
            C_mem[0]  <= C11[31:0];  C_mem[1]  <= C11[63:32];
            C_mem[2]  <= C12[31:0];  C_mem[3]  <= C12[63:32];
            C_mem[4]  <= C13[31:0];  C_mem[5]  <= C13[63:32];
            C_mem[6]  <= C14[31:0];  C_mem[7]  <= C14[63:32];

            C_mem[8]  <= C21[31:0];  C_mem[9]  <= C21[63:32];
            C_mem[10] <= C22[31:0];  C_mem[11] <= C22[63:32];
            C_mem[12] <= C23[31:0];  C_mem[13] <= C23[63:32];
            C_mem[14] <= C24[31:0];  C_mem[15] <= C24[63:32];

            C_mem[16] <= C31[31:0];  C_mem[17] <= C31[63:32];
            C_mem[18] <= C32[31:0];  C_mem[19] <= C32[63:32];
            C_mem[20] <= C33[31:0];  C_mem[21] <= C33[63:32];
            C_mem[22] <= C34[31:0];  C_mem[23] <= C34[63:32];

            C_mem[24] <= C41[31:0];  C_mem[25] <= C41[63:32];
            C_mem[26] <= C42[31:0];  C_mem[27] <= C42[63:32];
            C_mem[28] <= C43[31:0];  C_mem[29] <= C43[63:32];
            C_mem[30] <= C44[31:0];  C_mem[31] <= C44[63:32];

            start <= 0;
            cstate <= S_DONE;
            
        end

        S_DONE: begin
            // Wait for master to clear start=0 before returning to IDLE
            if (!start) begin
                busy       <= 0;
                irq_en     <= 1;
                irq_status <= 1;
                cstate     <= S_IDLE;
            end
        end

        endcase
    end
end

//////////////////// WRITE FSM ////////////////////
// FIX 1: aw_latched ensures waddr is fully captured before WREADY
//         is asserted - correct AXI behaviour for independent channels
// FIX 2: W_DATA burst counter only increments for mapped addresses,
//         preventing W_RESP from overriding W_RESP_N on unmapped writes
// FIX 3: W_RESP_N sets BRESP=2'b11 BEFORE checking BREADY so master
//         samples the correct error response on the handshake edge
always @(posedge ACLK) begin
    if (ARESETN) begin
        aw_latched <= 0;
        AWREADY    <= 0;
        WREADY     <= 0;
        BVALID     <= 0;
        BRESP      <= 2'b00;
        wstate     <= W_IDLE;
    end else begin
        case(wstate)

        W_IDLE: begin
            AWREADY <= 1;
            BRESP   <= 2'b00;
            BVALID  <= 0;
            WREADY  <= 0;   // hold WREADY low until address is safely latched
            if (AWVALID) begin
                waddr      <= AWADDR;
                wlen_cnt   <= AWLEN;
//                WREADY <= 1;        // address latched - now accept write data
                aw_latched <= 1;
            end
            if (WVALID && aw_latched) begin
                    aw_latched <= 0;
                    wstate     <= W_DATA;
                end
            
        end

        W_DATA: begin
            WREADY <= 1;
            AWREADY <= 0;
            if (WVALID) begin
                 if (waddr == CTRL_ADDR) begin
                    start <= WDATA[0];
                end
                else if (waddr >= A_BASE && waddr <= (A_BASE + 32'h3C))
                    A_mem[(waddr - A_BASE)>>2] <= WDATA;
                else if (waddr >= B_BASE && waddr <= (B_BASE + 32'h3C))
                    B_mem[(waddr - B_BASE)>>2] <= WDATA;
                else begin
                    wstate <= W_RESP_N;  
                end
                // Burst counter only for mapped addresses
                if (waddr == CTRL_ADDR || (waddr >= A_BASE && waddr <= (A_BASE + 32'h3C)) || (waddr >= B_BASE && waddr <= (B_BASE + 32'h3C))) begin
//                    if (wlen_cnt == 0)
//                        wstate <= W_RESP;
                      if (WLAST)
                          wstate <=W_RESP;
                      else begin
                           waddr    <= waddr + 4;
                           wlen_cnt <= wlen_cnt - 1;
                    end
                end
            end
        end

        W_RESP: begin
            WREADY <= 0;
            BVALID <= 1;
            BRESP  <= 2'b00;    // OKAY response
            if (BREADY) begin
//                BVALID <= 0;
                wstate <= W_IDLE;
            end
        end

        W_RESP_N: begin
            WREADY <= 0;
            BVALID <= 1;
            BRESP  <= 2'b11;    // DECERR - set BEFORE BREADY so master samples correctly
            if (BREADY) begin
                 wstate <= W_IDLE;
//                BVALID <= 0;
//                BRESP  <= 2'b00;
            end
        end

        endcase
    end
end

//////////////////// READ FSM ////////////////////
// FIX: RLAST initialised to 0 in reset block (was missing, caused X on RLAST)
// FIX: irq_status and irq_en clear wrapped in begin/end (was missing, caused
//      irq_en to unconditionally clear every cycle in R_DATA state)
always @(posedge ACLK) begin
    if (ARESETN) begin
        ARREADY <= 0;
        RVALID  <= 0;
        RDATA   <= 32'h00000000;
        RRESP   <= 2'b00;
        RLAST   <= 0; 
        rstate  <= R_IDLE;          
    end else begin
        case(rstate)
        R_IDLE: begin
            RVALID  <= 0;
            RRESP  <= 2'b00;
            RLAST  <= 0;
            if (ARVALID) begin
                raddr    <= ARADDR;
                rlen_cnt <= ARLEN;
                ARREADY <= 1;              
                rstate   <= R_DATA;
            end
        end

        R_DATA: begin
            ARREADY <= 0;
//            RVALID  <= 1;
            if (raddr == CTRL_ADDR) begin
                RDATA <= {28'b0, irq_status, irq_en, busy, start};
                RVALID <= 1;
                RRESP <= 2'b00;
                if (RVALID && RREADY) begin  // FIX: begin/end added
                    irq_status <= 0;          // was: irq_en cleared unconditionally
                    irq_en     <= 0;
                end
            end
            else if (raddr >= A_BASE && raddr <= (A_BASE + 32'h3C)) begin
                RDATA <= A_mem[(raddr - A_BASE)>>2];
                RVALID  <= 1;
                RRESP <= 2'b00;
            end
            else if (raddr >= B_BASE && raddr <= (B_BASE + 32'h3C)) begin
                RDATA <= B_mem[(raddr - B_BASE)>>2];
                RVALID  <= 1;
                RRESP <= 2'b00;
            end
            else if (raddr >= C_BASE && raddr <= (C_BASE + 32'h7C)) begin
                RDATA <= C_mem[(raddr - C_BASE)>>2];
                RVALID  <= 1;
                RRESP <= 2'b00;
            end
            else
                rstate <= R_RESP_N;

            if (rlen_cnt == 0) begin
                RLAST <= 1;
                if (RREADY) begin
                    RVALID <= 0;
                    RLAST  <= 0;
                    rstate <= R_IDLE;
                end
            end else begin
                if (RREADY) begin
                    raddr    <= raddr + 4;
                    rlen_cnt <= rlen_cnt - 1;
                end
            end
        end

        R_RESP_N: begin
//            RVALID <= 1;
//            RRESP  <= 2'b11;    // DECERR for unmapped read address
//            RLAST  <= 1;
            if (RREADY) begin
                RVALID <= 1;
                RLAST  <= 1;
                RRESP  <= 2'b11;
                rstate <= R_IDLE;
            end
        end

        endcase
    end
end

//////////////////// INTERRUPT ////////////////////
wire irq;
assign irq = irq_en & irq_status;

endmodule