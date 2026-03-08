
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
wire [31:0] RD1E, RD2E;
wire  [4:0] Rs1E, Rs2E;
wire  [3:0] ALUControlE;
wire  [2:0] funct3E;

wire [31:0] ALUSrcA, ALUSrcB;
wire StallF, StallD, FlushD, FlushE;
wire  [1:0] ForwardAE, ForwardBE;

wire        BP_predict_taken;
wire [31:0] BP_predicted_target;
wire        BP_prediction_valid;
wire        BP_update_en;
wire        BranchMispredictE;

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

wire BranchActuallyTaken;
wire [31:0] MispredictCorrectPC;

// PC source in Execute: ONLY assert when PC needs correction
// With speculative prediction, correctly predicted branches don't need Execute intervention
// Only mispredictions, unpredicted jumps, or JALR need to update PC from Execute
wire PCSrcE = JumpE || JalrE || BranchMispredictE;

// Branch Predictor instantiation
// SPECULATIVE: Predicts immediately based on BTB hit, doesn't wait for decode
wire BP_PCSrc = BP_predict_taken && BP_prediction_valid;
branch_predictor bp (
    clk, reset, PCF, BP_predict_taken, BP_predicted_target, BP_prediction_valid,
    BP_update_en, PCE, PCTargetE, Branch && BranchE
);

wire PCSrc_predict = BP_PCSrc && !PCSrcE;  // Use prediction only if Execute not overriding
wire [31:0] PC_pred_or_plus4 = PCSrc_predict ? BP_predicted_target : PCPlus4F;

// Select correct PC based on Execute stage outcomes
// Priority: Jump/Mispredict > Normal branch > Prediction/PC+4
wire [31:0] PCTarget_corrected;
assign PCTarget_corrected = BranchMispredictE ? MispredictCorrectPC :
                           (JumpE || (BranchActuallyTaken && !BranchMispredictE)) ? PCTargetE :
                           PCPlus4E;  // Fallback (shouldn't reach here if PCSrcE logic correct)

// next PC logic
mux2 #(32) pcmux (PC_pred_or_plus4, PCTarget_corrected, PCSrcE, PCNext);
mux2 #(32) jalrmux (PCNext, ALUResultE, JalrE, PCJalr);

reset_ff   pcreg (clk, reset, StallF, PCJalr, PCF);
bk_adder   pcadd4 (PCF, 32'd4, 1'b0, PCPlus4F, unused[0]);

// Shadow PC registers - capture PC at fetch time for sequential IMEM alignment
reg [31:0] PCF_shadow, PCPlus4F_shadow;
reg BP_was_predicted_taken;  // Was branch predicted taken in Fetch?
always @(posedge clk) begin
    if (!reset) begin
        PCF_shadow <= 0;
        PCPlus4F_shadow <= 4;
        BP_was_predicted_taken <= 0;
    end else if (!StallF) begin
        PCF_shadow <= PCF;
        PCPlus4F_shadow <= PCPlus4F;
        BP_was_predicted_taken <= BP_PCSrc;  // Save if we predicted branch taken
    end
end

// Decode Pipeline register - receives instruction and its captured PC together
pl_reg_d pld (clk, StallD, FlushD, Instr, PCF_shadow, PCPlus4F_shadow,
              InstrD, PCD, PCPlus4D);

// Track branch prediction through pipeline stages
reg BP_predicted_taken_D, BP_predicted_taken_E;
always @(posedge clk) begin
    if (!StallD && !FlushD)
        BP_predicted_taken_D <= BP_was_predicted_taken;
    else if (FlushD)
        BP_predicted_taken_D <= 0;

    if (!FlushE)
        BP_predicted_taken_E <= BP_predicted_taken_D;
    else
        BP_predicted_taken_E <= 0;
end

// Misprediction detection in Execute stage
assign BranchActuallyTaken = Branch && BranchE;
wire FalsePrediction = BP_predicted_taken_E && !BranchE;  // Predicted branch but wasn't one
wire WrongBranchOutcome = BranchE && (BP_predicted_taken_E != BranchActuallyTaken);

assign BranchMispredictE = FalsePrediction || WrongBranchOutcome;
assign BP_update_en = BranchE;

assign MispredictCorrectPC = BranchActuallyTaken ? PCTargetE : PCPlus4E;

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

// Store masker for store operations - generates byte enables and aligns data
wire [31:0] AlignedWriteDataM;
wire  [3:0] weaM;
store_masker store_mask (funct3M, ALUResultM[1:0], WriteDataM, AlignedWriteDataM, weaM);

// Memory masker for load operations
load_masker load_mask (funct3W, ALUResultW[1:0], ReadData, MaskedReadDataW);

// Result Source
mux4 #(32) resultmux (ALUResultW, MaskedReadDataW, PCPlus4W, lAuiPCW, ResultSrcW, ResultW);

hazard_unit hz (
    clk, reset, InstrD[19:15], InstrD[24:20], Rs1E, Rs2E, RdE, RdM, RdW, ResultSrcE[0], RegWriteM, RegWriteW, PCSrcE,
    StallF, StallD, FlushD, FlushE, ForwardAE, ForwardBE
);

assign Mem_WrData = AlignedWriteDataM;
assign Mem_WrAddr = ALUResultM;
assign wea = MemWriteM ? weaM : 4'b0000;

endmodule