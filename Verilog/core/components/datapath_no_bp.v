// datapath_no_bp.v
module datapath_no_bp (
    input         clk, reset,
    input [1:0]   ResultSrcD,
    input         ALUSrcD,
    input         RegWriteD,
    input [1:0]   ImmSrcD,
    input [4:0]   ALUControlD,
    input         JalrD, csrSelD,
    output [31:0] PCF,
    input  [31:0] Instr,
    output [31:0] Mem_WrAddr, Mem_WrData,
    output  [3:0] wea,
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
wire [31:0] rs1, RD1E, RD2E;
wire  [4:0] ALUControlE;
wire  [2:0] funct3E;

wire [31:0] ALUSrcA, ALUSrcB;
wire ALUStall, StallF, StallD, FlushD, FlushE;
wire  [1:0] ForwardAE, ForwardBE;

wire        RegWriteE, RegWriteM, RegWriteW;
wire  [1:0] ResultSrcE, ResultSrcM, ResultSrcW;
wire        MemWriteE;

wire [31:0] ALUResultE, ALUResultM;

wire [31:0] PCD, PCE, PCM;
wire [31:0] InstrE, WriteDataM;

wire  [4:0] RdM, RdW;
wire [31:0] ImmExtD, ImmExtE;
wire [31:0] lAuiPCD, lAuiPCE, lAuiPCM, lAuiPCW;
wire [31:0] PCPlus4F, PCPlus4D, PCPlus4E, PCPlus4M, PCPlus4W;

wire [31:0] ReadDataW;
wire  [2:0] funct3W;
wire Zero, Branch, BranchE;
wire unused[2:0];
wire ivalid;

wire        BranchTakenE;
wire        FetchHold, DecodeHold;
wire        PCSrcE;

// Dummy wires for unused pl_reg_d/pl_reg_e prediction outputs
wire        PredTakenD_unused;
wire [31:0] PredTargetD_unused;
wire        PredTakenE_unused;
wire [31:0] PredTargetE_unused;

// No branch predictor: always fetch PC+4, redirect on any taken branch or jump
assign BranchTakenE   = BranchE && Branch;
assign PCSrcE         = JumpE || JalrE || BranchTakenE;

// PCSrcE overrides stall so a flush always redirects the PC
assign FetchHold  = (StallF || ALUStall) && !PCSrcE;
assign DecodeHold = StallD || ALUStall;

wire [31:0] BranchRecoveryPCE    = BranchTakenE ? PCTargetE : PCPlus4E;
wire [31:0] ExecuteNextPCCandidate = JumpE ? PCTargetE : BranchRecoveryPCE;

// next PC: PC+4 unless execute redirects
mux2 #(32) pcmux (PCPlus4F, ExecuteNextPCCandidate, (JumpE || BranchTakenE), PCNext);
mux2 #(32) jalrmux (PCNext, ALUResultE, JalrE, PCJalr);

reset_ff   pcreg   (clk, reset, FetchHold, PCJalr, PCF);
bk_adder   pcadd4  (PCF, 32'd4, 1'b0, PCPlus4F, unused[0]);

// Decode pipeline register — no prediction (pass 0s)
pl_reg_d pld (clk, DecodeHold, FlushD, Instr, PCF, PCPlus4F, 1'b0, 32'h0,
              InstrD, PCD, PCPlus4D, PredTakenD_unused, PredTargetD_unused);

// Register file logic
reg_file   rf  (clk, RegWriteW, InstrD[19:15], InstrD[24:20], RdW, ResultW, rs1, WriteData);
imm_extend ext (InstrD[31:7], ImmSrcD, ImmExtD);
assign SrcA = (csrSelD && InstrD[14]) ? {{27{1'b0}}, InstrD[19:15]} : rs1;

bk_adder   auipcadder ({InstrD[31:12], 12'b0}, PCD, 1'b0, AuiPC, unused[1]);
mux2 #(32) lauipcmux  (AuiPC, {InstrD[31:12], 12'b0}, InstrD[5], lAuiPCD);

// Execute pipeline register — pred inputs tied to 0
pl_reg_e ple (
    clk, FlushE, ALUStall, ResultSrcD, MemWriteD, ALUSrcD, RegWriteD, JumpD, JalrD, ALUControlD, BranchD, SrcA, WriteData, PCD, InstrD, ImmExtD, PCPlus4D, lAuiPCD, InstrD[14:12], 1'b0, 32'h0,
    ResultSrcE, MemWriteE, ALUSrcE, RegWriteE, JumpE, JalrE, ALUControlE, BranchE, RD1E, RD2E, PCE, InstrE, ImmExtE, PCPlus4E, lAuiPCE, funct3E, PredTakenE_unused, PredTargetE_unused
);

// ALU logic
mux3 #(32) srcamux (RD1E, ResultW, ALUResultM, ForwardAE, ALUSrcA);
mux3 #(32) rd2mux  (RD2E, ResultW, ALUResultM, ForwardBE, ALUSrcB);
bk_adder   pcaddbranch (PCE, ImmExtE, 1'b0, PCTargetE, unused[2]);

mux2 #(32) srcbmux (ALUSrcB, ImmExtE, ALUSrcE, SrcB);
alu        alu (clk, ALUSrcA, SrcB, ALUControlE, ALUResultE, Zero, ALUStall);
wire [31:0] placeholder;
csr_handler csr (clk, reset, !FlushE && InstrE, 1'b0, InstrD[31:20], SrcA, placeholder);

branching_unit bu (funct3E, Zero, ALUResultE[31], Branch);

pl_reg_m plm (
    clk, reset, ALUStall, ResultSrcE, MemWriteE, RegWriteE, ALUResultE, ALUSrcB, InstrE[11:7], PCPlus4E, lAuiPCE, funct3E, PCE,
    ResultSrcM, MemWriteM, RegWriteM, ALUResultM, WriteDataM, RdM, PCPlus4M, lAuiPCM, funct3M, PCM
);

pl_reg_w plw (
    clk, reset, ResultSrcM, RegWriteM, ALUResultM, ReadData, RdM, PCPlus4M, lAuiPCM, PCM, WriteDataM, funct3M,
    ResultSrcW, RegWriteW, ALUResultW, ReadDataW, RdW, PCPlus4W, lAuiPCW, PCW, WriteDataW, funct3W
);

wire [31:0] AlignedWriteDataM;
wire  [3:0] weaM;
store_masker store_mask (funct3M, ALUResultM[1:0], WriteDataM, AlignedWriteDataM, weaM);
load_masker  load_mask  (funct3W, ALUResultW[1:0], ReadData, MaskedReadDataW);

mux4 #(32) resultmux (ALUResultW, MaskedReadDataW, PCPlus4W, lAuiPCW, ResultSrcW, ResultW);

hazard_unit hz (
    clk, reset, InstrD[19:15], InstrD[24:20], InstrE[19:15], InstrE[24:20], InstrE[11:7], RdM, RdW, ResultSrcE[0], RegWriteM, RegWriteW, PCSrcE,
    StallF, StallD, FlushD, FlushE, ForwardAE, ForwardBE
);

assign Mem_WrData = AlignedWriteDataM;
assign Mem_WrAddr = ALUResultM;
assign wea = MemWriteM ? weaM : 4'b0000;

endmodule
