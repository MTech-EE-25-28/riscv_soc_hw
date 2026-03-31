
// 32-bit Brent-Kung Adder
module bk_adder #(parameter WIDTH=32) (
    input  [WIDTH-1:0] A,
    input  [WIDTH-1:0] B,
    input  CIN,
    output [WIDTH-1:0] SUM,
    output COUT
);

wire [31:0] P0,G0;
wire [15:0] P1,G1;
wire [7:0] P2,G2;
wire [3:0] P3,G3;
wire [1:0] P4,G4;
wire [0:0] P5,G5;
wire [32:0] C;

wire [31:0] B_Mod = B ^ {32{CIN}};

// PG Generation
assign P0 = A ^ B_Mod;
assign G0 = A & B_Mod;

genvar i;
generate
    for(i=0;i<=15;i=i+1) begin : level_1
        BlackCell  bc(G0[2*i+1],P0[2*i+1],G0[2*i],P0[2*i],P1[i],G1[i]);
    end
endgenerate

generate
    for(i=0;i<=7;i=i+1) begin : level_2
        BlackCell  bc(G1[2*i+1],P1[2*i+1],G1[2*i],P1[2*i],P2[i],G2[i]);
    end
endgenerate

generate
    for(i=0;i<=3;i=i+1) begin : level_3
        BlackCell  bc(G2[2*i+1],P2[2*i+1],G2[2*i],P2[2*i],P3[i],G3[i]);
    end
endgenerate

generate
    for(i=0;i<=1;i=i+1) begin : level_4
        BlackCell  bc(G3[2*i+1],P3[2*i+1],G3[2*i],P3[2*i],P4[i],G4[i]);
    end
endgenerate

generate
    for(i=0;i<=0;i=i+1) begin : level_5
        BlackCell  bc(G4[2*i+1],P4[2*i+1],G4[2*i],P4[2*i],P5[i],G5[i]);
    end
endgenerate

assign C[0] = CIN;

assign C[1] = G0[0] | (P0[0]&C[0]);
assign C[2] = G1[0] | (P1[0]&C[0]);
assign C[4] = G2[0] | (P2[0]&C[0]);
assign C[8] = G3[0] | (P3[0]&C[0]);
assign C[16] = G4[0] | (P4[0]&C[0]);
assign C[32] = G5[0] | (P5[0]&C[0]);

assign C[24] = G3[2] | (P3[2]&C[16]);

assign C[12] = G2[2] | (P2[2]&C[8]);
assign C[20] = G2[4] | (P2[4]&C[16]);
assign C[28] = G2[6] | (P2[6]&C[24]);

assign C[6] = G1[2] | (P1[2]&C[4]);
assign C[10] = G1[4] | (P1[4]&C[8]);
assign C[14] = G1[6] | (P1[6]&C[12]);
assign C[18] = G1[8] | (P1[8]&C[16]);
assign C[22] = G1[10] | (P1[10]&C[20]);
assign C[26] = G1[12] | (P1[12]&C[24]);
assign C[30] = G1[14] | (P1[14]&C[28]);

assign C[3] = G0[2] | (P0[2]&C[2]);
assign C[5] = G0[4] | (P0[4]&C[4]);
assign C[7] = G0[6] | (P0[6]&C[6]);
assign C[9] = G0[8] | (P0[8]&C[8]);
assign C[11] = G0[10] | (P0[10]&C[10]);
assign C[13] = G0[12] | (P0[12]&C[12]);
assign C[15] = G0[14] | (P0[14]&C[14]);
assign C[17] = G0[16] | (P0[16]&C[16]);
assign C[19] = G0[18] | (P0[18]&C[18]);
assign C[21] = G0[20] | (P0[20]&C[20]);
assign C[23] = G0[22] | (P0[22]&C[22]);
assign C[25] = G0[24] | (P0[24]&C[24]);
assign C[27] = G0[26] | (P0[26]&C[26]);
assign C[29] = G0[28] | (P0[28]&C[28]);
assign C[31] = G0[30] | (P0[30]&C[30]);

// Postprocessing
assign SUM[31:0] = P0[31:0] ^ C[31:0];
assign COUT = C[32];

endmodule

// black Cell Module
module BlackCell(
    input A, B, C, D,
    output E, F
);

assign E = B & D;
assign F = A | (B & C);

endmodule