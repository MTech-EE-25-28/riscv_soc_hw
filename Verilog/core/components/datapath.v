
// datapath.v
module datapath (
    input         clk, reset,
    input [4:0]   interruptA,
    input [1:0]   ResultSrcD,
    input         ALUSrcD,
    input         RegWriteD,
    input [1:0]   ImmSrcD,
    input [4:0]   ALUControlD,
    input         JalrD, csrSelD, ierrD, ecallD,
    input         ebreakD, wfiD, retD,
    output [31:0] PCF,
    input  [31:0] Instr,
    output [31:0] Mem_WrAddr, Mem_WrData,
    output  [3:0] wea,
    input  [31:0] ReadData,
    output [31:0] ResultW, InstrD,
    input         MemWriteD, JumpD, BranchD,
    output        MemWriteM,
    output  [2:0] funct3M,
    output [31:0] PCW, ALUResultW, WriteDataW, MaskedReadDataW,
    input          mem_stall  // stall all stages during APB peripheral access
);

// signal definitions
// Pipeline control
wire        ALUStall;
wire        StallF,  StallD,  FlushD,  FlushE;
wire  [1:0] ForwardAE, ForwardBE;
wire        FetchHold, DecodeHold;
wire        PCSrcE, PCSrcTrap;

// PC pipeline
wire [31:0] PCJalr, PCAfterExec, PCAfterJalr, AuiPC;
wire [31:0] PCPlus4F, PCPlus4D, PCPlus4E, PCPlus4M, PCPlus4W;
wire [31:0]          PCD,       PCE,       PCM;       // PCF = module output
wire [31:0]          PCTargetE, PCTargetM;
wire [31:0] lAuiPCD, lAuiPCE,  lAuiPCM,  lAuiPCW;
wire        validD, validE, validM;
// Instruction / alignment pipeline
wire [31:0] InstrE;                   // InstrD = module output
wire        misAlignF, misAlignD;
wire [31:0] ImmExtD, ImmExtE;

// Register file / operands
wire [31:0] rs1, SrcA, SrcB, WriteData;
wire [31:0] ALUSrcA, ALUSrcB;
wire [31:0] RD1E, RD2E;
wire  [4:0] RdM, RdW;
wire [31:0] WriteDataM;

// ALU / result pipeline
wire [31:0] ALUResultE, ResultE, ResultM;
wire [31:0] ReadDataW;                // ResultW = module output
wire [31:0] CSRResultE;
wire        Zero, ALUSrcE;

// Decoded control signals pipeline
wire        RegWriteE,  RegWriteM,  RegWriteW;
wire  [1:0] ResultSrcE, ResultSrcM, ResultSrcW;
wire        MemWriteE;               // MemWriteM = module output
wire  [4:0] ALUControlE;
wire  [2:0] funct3E,  funct3W;       // funct3M = module output
wire        JumpE, JalrE, BranchE, csrSelE;

// Branch prediction pipeline
wire        BPPredictTakenF,  BPPredictionValidF;
wire        PredTakenF,  PredTakenD,  PredTakenE;
wire [31:0] PredTargetF, PredTargetD, PredTargetE;
wire [31:0] FetchNextPCCandidate, BranchRecoveryPCE, ExecuteNextPCCandidate;
wire        BranchTakenE, BranchM,    BranchTakenM;
wire        BranchDirectionMissE, FalseBranchPredictionE, BranchMispredictE;
wire        JumpMispredictE;

// Exception pipeline  D -> E -> M -> W
// excDec encoding: [2]=ecall  [1]=fetch-misalign  [0]=illegal // ebreak ignored
// exceptionW encoding: [5]=store-misalign [4]=load-misalign [3]=ebreak [2]=ecall [1]=fetch-misalign [0]=illegal
wire [3:0]  excDecD,            excDecE,             excDecM,             excDecW;
wire        tretD,              tretE,               tretM,               tretW;
wire        memMisAlignLoadM,   memMisAlignLoadW;
wire        memMisAlignStoreM,  memMisAlignStoreW;
wire [5:0]  exceptionW;

// Trap / CSR interface
wire        trap_event, trap_active;
wire [31:0] trap_pc_next,      trap_mepc,      trap_mcause,    trap_mtval;
wire        trap_mstatus_mie,  trap_mstatus_mpie;
wire        tret_mstatus_mie,  tret_mstatus_mpie;
wire [31:0] csr_mstatus, csr_mie,      csr_mip,      csr_mtvec;
wire [31:0] csr_mepc,    csr_mcause,   csr_mscratch, csr_mtval;

// Misc
wire unused[2:0];

assign PCSrcTrap  = trap_event;
assign misAlignF  = (PCF[1:0] != 2'b00);

assign FetchHold  = (StallF || ALUStall || misAlignF) && !PCSrcE && !PCSrcTrap;
assign DecodeHold = StallD || ALUStall;

// -------------------------------------------------------------------------
// Fetch stage

// branch predictor
branch_predictor bp (
    clk, reset, 1'b1, PCF, BPPredictTakenF, PredTargetF, BPPredictionValidF,
    BranchM, PCM, PCTargetM, BranchTakenM
);

assign PredTakenF           = BPPredictTakenF && BPPredictionValidF;
assign FetchNextPCCandidate = PredTakenF ? PredTargetF : PCPlus4F;
assign BranchTakenE         = BranchE && Branch;

// Case 1: Branch direction misprediction: predicted taken/not-taken differs from actual
// Case 2: Branch target misprediction: predicted target differs from actual, when both predicted and actual are taken
// Case 3: False branch prediction: predicted taken but not a branch instruction
// on any of these cases, we need to recover by flushing the incorrect instructions and updating the PC to the correct target
// XOR Branch directly with PredTakenE — avoids extra AND gate (BranchTakenE) on critical path
assign BranchDirectionMissE   = BranchE && (PredTakenE ^ Branch);
assign FalseBranchPredictionE = PredTakenE && !BranchE && !JumpE;
assign BranchMispredictE      = FalseBranchPredictionE || BranchDirectionMissE;
// assign BranchTargetMissE      = BranchE && PredTakenE && BranchTakenE && (PredTargetE != PCTargetE);
// MCU (<8KB): alias probability near-zero, skip 32-bit target compare on critical path (Remove BranchTargetMissE)
assign JumpMispredictE  = JumpE && !PredTakenE;
assign PCSrcE           = JumpMispredictE || JalrE || BranchMispredictE;

// If branch taken, use branch target, else PC+4
// If jump, use jump target, else branch recovery PC
assign BranchRecoveryPCE      = BranchTakenE ? PCTargetE : PCPlus4E;
assign ExecuteNextPCCandidate = JumpE ? PCTargetE : BranchRecoveryPCE;

// PC mux chain: branch/jump override, then JALR override, then trap override
mux2 #(32) pcmux   (FetchNextPCCandidate, ExecuteNextPCCandidate, (JumpMispredictE || BranchMispredictE), PCAfterExec);
mux2 #(32) jalrmux (PCAfterExec, ALUResultE, JalrE, PCAfterJalr);
mux2 #(32) trapmux (PCAfterJalr, trap_pc_next, PCSrcTrap, PCJalr);

reset_ff   pcreg (clk, reset, FetchHold, PCJalr, PCF);
bk_adder   pcadd4 (PCF, 32'd4, 1'b0, PCPlus4F, unused[0]);

// -------------------------------------------------------------------------
// Decode stage
pl_reg_d pld (
    clk, DecodeHold, FlushD,
    Instr, PCF, PCPlus4F, PredTakenF, misAlignF, PredTargetF,
    InstrD, PCD, PCPlus4D, PredTakenD, misAlignD, PredTargetD, validD
);

// Register file
reg_file   rf (clk, RegWriteW, InstrD[19:15], InstrD[24:20], RdW, ResultW, rs1, WriteData);
imm_extend ext (InstrD[31:7], ImmSrcD, ImmExtD);

// CSR source A mux: zimm (rs1 field as 5-bit zero-extended) or rs1 register
assign SrcA = (csrSelD && InstrD[14]) ? {{27{1'b0}}, InstrD[19:15]} : rs1;

bk_adder   auipcadder ({InstrD[31:12], 12'b0}, PCD, 1'b0, AuiPC, unused[1]);
mux2 #(32) lauipcmux  (AuiPC, {InstrD[31:12], 12'b0}, InstrD[5], lAuiPCD);

// Pack decode-stage exceptions: [3]=ebreak [2]=ecall [1]=fetch-misalign [0]=illegal
assign excDecD = {ebreakD, ecallD, misAlignD, ierrD};
assign tretD   = retD;

// CSR handler
// Reads happen in Decode (for the CSR read value forwarded to Execute).
// Writes / trap commits happen on negedge clk, driven by WB-stage trap signals.
// ivalid: instruction in Execute stage is valid (not flushed).
wire ivalid_csr = !FlushE && !ALUStall && !mem_stall; // don't re-commit CSR writes during APB stalls
csr_handler csr (
    clk, reset, ivalid_csr, csrSelE, InstrE[13:12], InstrE[31:20], ALUSrcA, CSRResultE,
    // trap from WB-stage error_handler
    trap_active, trap_mstatus_mie, trap_mstatus_mpie, trap_mepc, trap_mcause, trap_mtval,
    // trap return
    tretW, tret_mstatus_mie, tret_mstatus_mpie,
    // csr output fields
    csr_mstatus, csr_mie, csr_mip, csr_mtvec, csr_mepc, csr_mcause, csr_mscratch, csr_mtval
);

// -------------------------------------------------------------------------
// Execute stage
pl_reg_e ple (
    clk, FlushE, ALUStall || mem_stall, ResultSrcD, csrSelD, MemWriteD, ALUSrcD, RegWriteD, JumpD, JalrD, ALUControlD, BranchD,
    SrcA, WriteData, PCD, InstrD, ImmExtD, PCPlus4D, lAuiPCD, InstrD[14:12], PredTakenD, PredTargetD, excDecD, tretD, validD,
    ResultSrcE, csrSelE, MemWriteE, ALUSrcE, RegWriteE, JumpE, JalrE, ALUControlE, BranchE, RD1E, RD2E, PCE, InstrE,
    ImmExtE, PCPlus4E, lAuiPCE, funct3E, PredTakenE, PredTargetE, excDecE, tretE, validE
);

// ALU logic
mux3 #(32) srcamux    (RD1E, ResultW, ResultM, ForwardAE, ALUSrcA);
mux3 #(32) rd2mux     (RD2E, ResultW, ResultM, ForwardBE, ALUSrcB);
bk_adder   pcaddbranch(PCE, ImmExtE, 1'b0, PCTargetE, unused[2]);

mux2 #(32) srcbmux (ALUSrcB, ImmExtE, ALUSrcE, SrcB);
alu        alu (clk, ALUSrcA, SrcB, ALUControlE, ALUResultE, Zero, ALUStall);

branching_unit bu (funct3E, Zero, ALUResultE[31], Branch);
mux2 #(32) csrmux (ALUResultE, CSRResultE, csrSelE, ResultE);

// -------------------------------------------------------------------------
// Memory stage — detect load/store alignment faults here
// Misaligned load: lh/lhu require addr[0]==0; lw requires addr[1:0]==00
// Misaligned store: sh requires addr[0]==0; sw requires addr[1:0]==00
// (byte accesses are always aligned)
wire isLoadM  = (ResultSrcE[0]); // ResultSrc[0]=1 => load (from execute going into M)
// detect in execute stage before registering, flag passes through pl_reg_m
wire misAlignLoad_pre  = (funct3E == 3'b001 || funct3E == 3'b101) ? ALUResultE[0]       // lh/lhu
                       : (funct3E == 3'b010)                       ? |ALUResultE[1:0]    // lw
                       : 1'b0;
wire misAlignStore_pre = (funct3E == 3'b001)                       ? ALUResultE[0]       // sh
                       : (funct3E == 3'b010)                       ? |ALUResultE[1:0]    // sw
                       : 1'b0;
wire misAlignLoadE  = misAlignLoad_pre  && !csrSelE && ResultSrcE[0]; // only for actual loads
wire misAlignStoreE = misAlignStore_pre && MemWriteE;                 // only for actual stores

pl_reg_m plm (
    clk, reset, ALUStall || mem_stall, PCSrcTrap, ResultSrcE, MemWriteE, RegWriteE, ResultE, ALUSrcB, InstrE[11:7], PCPlus4E, lAuiPCE, funct3E, PCE, BranchE, BranchTakenE, PCTargetE, excDecE, tretE, misAlignLoadE, misAlignStoreE, validE,
    ResultSrcM, MemWriteM, RegWriteM, ResultM, WriteDataM, RdM, PCPlus4M, lAuiPCM, funct3M, PCM, BranchM, BranchTakenM, PCTargetM, excDecM, tretM, memMisAlignLoadM, memMisAlignStoreM, validM
);

// Suppress memory write when store is misaligned (prevent corrupt writes)
wire MemWriteM_safe = MemWriteM && !memMisAlignStoreM;

// -------------------------------------------------------------------------
// Writeback stage
pl_reg_w plw (
    clk, reset, PCSrcTrap, mem_stall, ResultSrcM, RegWriteM, ResultM, ReadData, RdM, PCPlus4M, lAuiPCM, PCM, WriteDataM, funct3M, excDecM, tretM, memMisAlignLoadM, memMisAlignStoreM,
    ResultSrcW, RegWriteW, ALUResultW, ReadDataW, RdW, PCPlus4W, lAuiPCW, PCW, WriteDataW, funct3W, excDecW, tretW, memMisAlignLoadW, memMisAlignStoreW
);

// exceptionW encoding: [5]=store-misalign [4]=load-misalign [3]=ebreak [2]=ecall [1]=fetch-misalign [0]=illegal
assign exceptionW = {memMisAlignStoreW, memMisAlignLoadW, excDecW[3], excDecW[2], excDecW[1], excDecW[0]};

// Trap handler — sits entirely in Writeback, receives committed exceptions
trap_handler th (
    exceptionW, interruptA, tretW, PCW, PCM, PCE, validM, validE, ALUResultW, csr_mtvec, csr_mepc, csr_mstatus[3], csr_mstatus[7],
    trap_event, trap_pc_next, trap_mstatus_mie, trap_mstatus_mpie, trap_mepc, trap_mcause, trap_mtval, tret_mstatus_mie, tret_mstatus_mpie
);

// trap_active: only on exception/interrupt, not on tret (csr_handler has separate tret port)
assign trap_active = trap_event && !(|tretW);

// Suppress register writeback on the trapping instruction
wire RegWriteW_safe = RegWriteW && !trap_event;

// Store masker — generates byte enables and aligned write data
wire [31:0] AlignedWriteDataM;
wire  [3:0] weaM;
store_masker store_mask (funct3M, ResultM[1:0], WriteDataM, AlignedWriteDataM, weaM);

// Load masker — operates in Writeback (sequential BRAM read data arrives in WB)
load_masker load_mask (funct3W, ALUResultW[1:0], ReadData, MaskedReadDataW);

// Result mux
mux4 #(32) resultmux (ALUResultW, MaskedReadDataW, PCPlus4W, lAuiPCW, ResultSrcW, ResultW);

// -------------------------------------------------------------------------
// Hazard unit
// PCSrcTrap flushes the entire pipe (same mechanism as a branch redirect)
hazard_unit hz (
    clk, reset, InstrD[19:15], InstrD[24:20], InstrE[19:15], InstrE[24:20], InstrE[11:7], RdM, RdW,
    ResultSrcE[0], RegWriteM, RegWriteW_safe, PCSrcE || PCSrcTrap,
    mem_stall,
    StallF, StallD, FlushD, FlushE, ForwardAE, ForwardBE
);

assign Mem_WrData = AlignedWriteDataM;
assign Mem_WrAddr = ResultM;
assign wea        = MemWriteM_safe ? weaM : 4'b0000;

endmodule