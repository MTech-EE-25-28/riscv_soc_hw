
// datapath.v
module datapath (
    input         clk, reset,
    input [1:0]   ResultSrcD,
    input         ALUSrcD,
    input         RegWriteD,
    input [1:0]   ImmSrcD,
    input [3:0]   ALUControlD,
    input         JalrD,
    output [31:0] PCF,
    input  [31:0] Instr,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] ResultW, InstrD,
    input         MemWriteD, JumpD, BranchD,
    output        MemWriteM,
    output  [2:0] funct3M,
    output [31:0] PCW, ALUResultW, WriteDataW, MaskedReadDataW
);

wire [31:0] PCNext, PCJalr, PCTargetE, AuiPC;
wire [31:0] SrcA, SrcB, WriteData;

wire        ALUSrcE, JumpE, JalrE;
wire [31:0] RD1E, RD2E;
wire  [4:0] Rs1E, Rs2E;
wire  [3:0] ALUControlE;
wire  [2:0] funct3E;

wire [31:0] ALUSrcA, ALUSrcB;
wire StallF, StallD, FlushD, FlushE;
wire  [1:0] ForwardAE, ForwardBE;

wire        RegWriteE, RegWriteM, RegWriteW;
wire  [1:0] ResultSrcE, ResultSrcM, ResultSrcW;
wire        MemWriteE;

wire [31:0]  ALUResultE, ALUResultM;

wire [31:0] PCD, PCE, PCM;
wire [31:0] WriteDataM;

wire  [4:0] RdE, RdM, RdW;
wire [31:0] ImmExtD, ImmExtE;
wire [31:0] lAuiPCD, lAuiPCE, lAuiPCM, lAuiPCW;
wire [31:0] PCPlus4F, PCPlus4D, PCPlus4E, PCPlus4M, PCPlus4W;

wire [31:0] ReadDataW;  // Masked read data in writeback stage
wire  [2:0] funct3W;
wire Zero, Branch, BranchE;
wire unused[2:0];

wire PCSrcE = ((Branch && BranchE) || JumpE || JalrE) ? 1'b1 : 1'b0;

// next PC logic
mux2 #(32) pcmux (PCPlus4F, PCTargetE, PCSrcE, PCNext);
mux2 #(32) jalrmux (PCNext, ALUResultE, JalrE, PCJalr);

reset_ff   pcreg (clk, reset, StallF, PCJalr, PCF);
bk_adder   pcadd4 (PCF, 32'd4, 1'b0, PCPlus4F, unused[0]);

// Decode Pipeline register
pl_reg_d pld (clk, StallD, FlushD, Instr, PCF, PCPlus4F,
              InstrD, PCD, PCPlus4D);

// register file logic
reg_file   rf (clk, RegWriteW, InstrD[19:15], InstrD[24:20], RdW, ResultW, SrcA, WriteData);
imm_extend ext (InstrD[31:7], ImmSrcD, ImmExtD);

bk_adder   auipcadder ({InstrD[31:12], 12'b0}, PCD, 1'b0, AuiPC, unused[1]);
mux2 #(32) lauipcmux (AuiPC, {InstrD[31:12], 12'b0}, InstrD[5], lAuiPCD);

// Execute Pipeline register
pl_reg_e ple (
    clk, FlushE, ResultSrcD, MemWriteD, ALUSrcD, RegWriteD, JumpD, JalrD, ALUControlD, BranchD, SrcA, WriteData, PCD, InstrD[19:15], InstrD[24:20], InstrD[11:7], ImmExtD, PCPlus4D, lAuiPCD, InstrD[14:12],
    ResultSrcE, MemWriteE, ALUSrcE, RegWriteE, JumpE, JalrE, ALUControlE, BranchE, RD1E, RD2E, PCE, Rs1E, Rs2E, RdE, ImmExtE, PCPlus4E, lAuiPCE, funct3E
);

// ALU logic
mux3 #(32) srcamux (RD1E, ResultW, ALUResultM, ForwardAE, ALUSrcA);
mux3 #(32) rd2mux  (RD2E, ResultW, ALUResultM, ForwardBE, ALUSrcB);
bk_adder   pcaddbranch (PCE, ImmExtE, 1'b0, PCTargetE, unused[2]);

mux2 #(32) srcbmux (ALUSrcB, ImmExtE, ALUSrcE, SrcB);
alu        alu (ALUSrcA, SrcB, ALUControlE, ALUResultE, Zero);

branching_unit bu (funct3E, Zero, ALUResultE[31], Branch);

pl_reg_m plm (
    clk, reset, ResultSrcE, MemWriteE, RegWriteE, ALUResultE, ALUSrcB, RdE, PCPlus4E, lAuiPCE, funct3E, PCE,
    ResultSrcM, MemWriteM, RegWriteM, ALUResultM, WriteDataM, RdM, PCPlus4M, lAuiPCM, funct3M, PCM
);

pl_reg_w plw (
    clk, reset, ResultSrcM, RegWriteM, ALUResultM, ReadData, RdM, PCPlus4M, lAuiPCM, PCM, WriteDataM, funct3M,
    ResultSrcW, RegWriteW, ALUResultW, ReadDataW, RdW, PCPlus4W, lAuiPCW, PCW, WriteDataW, funct3W
);

// Memory masker for load operations - operates in Writeback stage for sequential BRAM
load_masker masker (funct3W, ALUResultW[1:0], ReadDataW, MaskedReadDataW);

// Result Source
mux4 #(32) resultmux (ALUResultW, MaskedReadDataW, PCPlus4W, lAuiPCW, ResultSrcW, ResultW);

hazard_unit hz (
    clk, reset, InstrD[19:15], InstrD[24:20], Rs1E, Rs2E, RdE, RdM, RdW, ResultSrcE[0], RegWriteM, RegWriteW, PCSrcE,
    StallF, StallD, FlushD, FlushE, ForwardAE, ForwardBE
);

assign Mem_WrData = WriteDataM;
assign Mem_WrAddr = ALUResultM;

endmodule