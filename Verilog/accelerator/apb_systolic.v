
module apb_systolic  #(
    parameter BASE_ADDR = 32'h0000_2100
) (
    input wire clk,
    input wire resetn,

    // APB Interface
    input wire  pclk,
    input wire  presetn,
    input wire  psel,
    input wire  penable,
    input wire  pwrite,
    input wire  [31:0] paddr,
    input wire  [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire pready,
    output reg  pslverr,

    // Interrupt
    output reg irq
);
// MM_MATA 32'h4 -> 16x4 =
localparam MM_CTSR = BASE_ADDR;         // BASE + 0x00
localparam MM_MATA = BASE_ADDR + 32'h4; // BASE + 0x04
localparam MM_MATB = BASE_ADDR + 32'h44; // BASE + 0x44
localparam MM_MATC = BASE_ADDR + 32'h84; // BASE + 0x84

reg start, done;
reg [31:0] MATA [15:0], MATB [15:0], MATC [15:0];

reg [31:0] A1, A2, A3, A4;
reg [31:0] B1, B2, B3, B4;
reg [3:0] compute_cycle;

wire [63:0] C11, C12, C13, C14;
wire [63:0] C21, C22, C23, C24;
wire [63:0] C31, C32, C33, C34;
wire [63:0] C41, C42, C43, C44;

systolic_4x4 systolic_inst (
    .clk(clk),
    .reset(~resetn),

    .A1(A1), .A2(A2), .A3(A3), .A4(A4),
    .B1(B1), .B2(B2), .B3(B3), .B4(B4),

    .C11(C11), .C12(C12), .C13(C13), .C14(C14),
    .C21(C21), .C22(C22), .C23(C23), .C24(C24),
    .C31(C31), .C32(C32), .C33(C33), .C34(C34),
    .C41(C41), .C42(C42), .C43(C43), .C44(C44)
);

always @(*) begin // apb read transaction
    if (psel && penable && !pwrite) begin
        case (paddr)
            MM_CTSR: prdata = {30'b0, done, start};
            MM_MATA + 0*4: prdata = MATA[0];
            MM_MATA + 1*4: prdata = MATA[1];
            MM_MATA + 2*4: prdata = MATA[2];
            MM_MATA + 3*4: prdata = MATA[3];
            MM_MATA + 4*4: prdata = MATA[4];
            MM_MATA + 5*4: prdata = MATA[5];
            MM_MATA + 6*4: prdata = MATA[6];
            MM_MATA + 7*4: prdata = MATA[7];
            MM_MATA + 8*4: prdata = MATA[8];
            MM_MATA + 9*4: prdata = MATA[9];
            MM_MATA + 10*4: prdata = MATA[10];
            MM_MATA + 11*4: prdata = MATA[11];
            MM_MATA + 12*4: prdata = MATA[12];
            MM_MATA + 13*4: prdata = MATA[13];
            MM_MATA + 14*4: prdata = MATA[14];
            MM_MATA + 15*4: prdata = MATA[15];
            MM_MATB + 0*4: prdata = MATB[0];
            MM_MATB + 1*4: prdata = MATB[1];
            MM_MATB + 2*4: prdata = MATB[2];
            MM_MATB + 3*4: prdata = MATB[3];
            MM_MATB + 4*4: prdata = MATB[4];
            MM_MATB + 5*4: prdata = MATB[5];
            MM_MATB + 6*4: prdata = MATB[6];
            MM_MATB + 7*4: prdata = MATB[7];
            MM_MATB + 8*4: prdata = MATB[8];
            MM_MATB + 9*4: prdata = MATB[9];
            MM_MATB + 10*4: prdata = MATB[10];
            MM_MATB + 11*4: prdata = MATB[11];
            MM_MATB + 12*4: prdata = MATB[12];
            MM_MATB + 13*4: prdata = MATB[13];
            MM_MATB + 14*4: prdata = MATB[14];
            MM_MATB + 15*4: prdata = MATB[15];
            MM_MATC +  0*4: prdata = MATC[0];
            MM_MATC +  1*4: prdata = MATC[1];
            MM_MATC +  2*4: prdata = MATC[2];
            MM_MATC +  3*4: prdata = MATC[3];
            MM_MATC +  4*4: prdata = MATC[4];
            MM_MATC +  5*4: prdata = MATC[5];
            MM_MATC +  6*4: prdata = MATC[6];
            MM_MATC +  7*4: prdata = MATC[7];
            MM_MATC +  8*4: prdata = MATC[8];
            MM_MATC +  9*4: prdata = MATC[9];
            MM_MATC + 10*4: prdata = MATC[10];
            MM_MATC + 11*4: prdata = MATC[11];
            MM_MATC + 12*4: prdata = MATC[12];
            MM_MATC + 13*4: prdata = MATC[13];
            MM_MATC + 14*4: prdata = MATC[14];
            MM_MATC + 15*4: prdata = MATC[15];
            default: prdata = 32'b0;
        endcase
    end else begin
        prdata = 32'b0;
    end
end

assign pready = (psel && penable) ? 1'b1 : 1'b0;

// APB write logic
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        start <= 1'b0;
        for (int i = 0; i < 16; i = i + 1) begin
            MATA[i] <= 32'b0;
            MATB[i] <= 32'b0;
        end
    end else if (psel && penable && pwrite) begin
        case (paddr)
            MM_CTSR: start <= pwdata[0];
            MM_MATA + 0*4: MATA[0] <= pwdata;
            MM_MATA + 1*4: MATA[1] <= pwdata;
            MM_MATA + 2*4: MATA[2] <= pwdata;
            MM_MATA + 3*4: MATA[3] <= pwdata;
            MM_MATA + 4*4: MATA[4] <= pwdata;
            MM_MATA + 5*4: MATA[5] <= pwdata;
            MM_MATA + 6*4: MATA[6] <= pwdata;
            MM_MATA + 7*4: MATA[7] <= pwdata;
            MM_MATA + 8*4: MATA[8] <= pwdata;
            MM_MATA + 9*4: MATA[9] <= pwdata;
            MM_MATA + 10*4: MATA[10] <= pwdata;
            MM_MATA + 11*4: MATA[11] <= pwdata;
            MM_MATA + 12*4: MATA[12] <= pwdata;
            MM_MATA + 13*4: MATA[13] <= pwdata;
            MM_MATA + 14*4: MATA[14] <= pwdata;
            MM_MATA + 15*4: MATA[15] <= pwdata;
            MM_MATB + 0*4: MATB[0] <= pwdata;
            MM_MATB + 1*4: MATB[1] <= pwdata;
            MM_MATB + 2*4: MATB[2] <= pwdata;
            MM_MATB + 3*4: MATB[3] <= pwdata;
            MM_MATB + 4*4: MATB[4] <= pwdata;
            MM_MATB + 5*4: MATB[5] <= pwdata;
            MM_MATB + 6*4: MATB[6] <= pwdata;
            MM_MATB + 7*4: MATB[7] <= pwdata;
            MM_MATB + 8*4: MATB[8] <= pwdata;
            MM_MATB + 9*4: MATB[9] <= pwdata;
            MM_MATB + 10*4: MATB[10] <= pwdata;
            MM_MATB + 11*4: MATB[11] <= pwdata;
            MM_MATB + 12*4: MATB[12] <= pwdata;
            MM_MATB + 13*4: MATB[13] <= pwdata;
            MM_MATB + 14*4: MATB[14] <= pwdata;
            MM_MATB + 15*4: MATB[15] <= pwdata;
        endcase
    end
end

// control FSM
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        A1 <= 32'b0; A2 <= 32'b0; A3 <= 32'b0; A4 <= 32'b0;
        B1 <= 32'b0; B2 <= 32'b0; B3 <= 32'b0; B4 <= 32'b0;
        done <= 1'b0; irq <= 1'b0; compute_cycle <= 4'b0;
        for (int i = 0; i < 16; i = i + 1) MATC[i] <= 32'b0;
    end else if (!start) begin
        done <= 1'b0; irq <= 1'b0; compute_cycle <= 4'b0;
    end else if (start && !done) begin
        compute_cycle <= compute_cycle + 1'b1;
        case (compute_cycle)
            4'b0000: begin
                A1 <= MATA[0]; A2 <= 0; A3 <= 0; A4 <= 0;
                B1 <= MATB[0]; B2 <= 0; B3 <= 0; B4 <= 0;
            end
            4'b0001: begin
                A1 <= MATA[1]; A2 <= MATA[4]; A3 <= 0; A4 <= 0;
                B1 <= MATB[4]; B2 <= MATB[1]; B3 <= 0; B4 <= 0;
            end
            4'b0010: begin
                A1 <= MATA[2]; A2 <= MATA[5]; A3 <= MATA[8]; A4 <= 0;
                B1 <= MATB[8]; B2 <= MATB[5]; B3 <= MATB[2]; B4 <= 0;
            end
            4'b0011: begin
                A1 <= MATA[3]; A2 <= MATA[6]; A3 <= MATA[9]; A4 <= MATA[12];
                B1 <= MATB[12]; B2 <= MATB[9]; B3 <= MATB[6]; B4 <= MATB[3];
            end
            4'b0100: begin
                A1 <= 0; A2 <= MATA[7]; A3 <= MATA[10]; A4 <= MATA[13];
                B1 <= 0; B2 <= MATB[13]; B3 <= MATB[10]; B4 <= MATB[7];
            end
            4'b0101: begin
                A1<=0; A2<=0; A3<=MATA[11]; A4<=MATA[14];
                B1<=0; B2<=0; B3<=MATB[14]; B4<=MATB[11];
            end
            4'b0110: begin
                A1<=0; A2<=0; A3<=0; A4<=MATA[15];
                B1<=0; B2<=0; B3<=0; B4<=MATB[15];
            end
            4'b1100: begin
                MATC[0]  <= C11[31:0]; // MATC[1]  <= C11[63:32];
                MATC[1]  <= C12[31:0]; // MATC[3]  <= C12[63:32];
                MATC[2]  <= C13[31:0]; // MATC[5]  <= C13[63:32];
                MATC[3]  <= C14[31:0]; // MATC[7]  <= C14[63:32];

                MATC[4]  <= C21[31:0]; // MATC[9]  <= C21[63:32];
                MATC[5] <= C22[31:0]; // MATC[11] <= C22[63:32];
                MATC[6] <= C23[31:0]; // MATC[13] <= C23[63:32];
                MATC[7] <= C24[31:0]; // MATC[15] <= C24[63:32];

                MATC[8] <= C31[31:0]; // MATC[17] <= C31[63:32];
                MATC[9] <= C32[31:0]; // MATC[19] <= C32[63:32];
                MATC[10] <= C33[31:0]; // MATC[21] <= C33[63:32];
                MATC[11] <= C34[31:0]; // MATC[23] <= C34[63:32];

                MATC[12] <= C41[31:0]; // MATC[25] <= C41[63:32];
                MATC[13] <= C42[31:0]; // MATC[27] <= C42[63:32];
                MATC[14] <= C43[31:0]; // MATC[29] <= C43[63:32];
                MATC[15] <= C44[31:0]; // MATC[31] <= C44[63:32];
                done <= 1'b1; irq <= 1'b1;
            end
            default: begin
                A1<=0; A2<=0; A3<=0; A4<=0;
                B1<=0; B2<=0; B3<=0; B4<=0;
            end
        endcase
    end
end

endmodule