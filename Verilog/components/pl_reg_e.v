
// pipeline registers execute stage
module pl_reg_e (
    input clk, clr, stall,
    input   [1:0] ResultSrcD,
    input         MemWriteD,
    input         ALUSrcD,
    input         RegWriteD, JumpD, JalrD,
    input   [4:0] ALUControlD,
    input         BranchD,
    input  [31:0] RD1D, RD2D,
    input  [31:0] PCD,
    input   [4:0] Rs1D, Rs2D, RdD,
    input  [31:0] ImmExtD, PCPlus4D, lAuiPCD,
    input   [2:0] funct3D,
    input         PredTakenD,
    input  [31:0] PredTargetD,
    output reg  [1:0] ResultSrcE,
    output reg        MemWriteE,
    output reg        ALUSrcE,
    output reg        RegWriteE, JumpE, JalrE,
    output reg  [4:0] ALUControlE,
    output reg        BranchE,
    output reg [31:0] RD1E, RD2E,
    output reg [31:0] PCE,
    output reg  [4:0] Rs1E, Rs2E, RdE,
    output reg [31:0] ImmExtE, PCPlus4E, lAuiPCE,
    output reg  [2:0] funct3E,
    output reg        PredTakenE,
    output reg [31:0] PredTargetE
);

always @(posedge clk) begin
    if (clr) begin
        RegWriteE <= 0; ResultSrcE <= 0; MemWriteE <= 0;
        JumpE <= 0; JalrE <= 0; BranchE <= 0; ALUControlE <= 0;
        ALUSrcE <= 0; PCE <= 0; Rs1E <= 0; Rs2E <= 0; RdE <= 0;
        ImmExtE <= 0; PCPlus4E <= 0; lAuiPCE <= 0; funct3E <= 0;
        PredTakenE <= 0; PredTargetE <= 0;
    end else if (!stall) begin
        RegWriteE <= RegWriteD; ResultSrcE <= ResultSrcD; MemWriteE <= MemWriteD;
        JumpE <= JumpD; JalrE <= JalrD; BranchE <= BranchD; ALUControlE <= ALUControlD;
        ALUSrcE <= ALUSrcD; RD1E <= RD1D; RD2E <= RD2D; PCE <= PCD; Rs1E <= Rs1D;
        Rs2E <= Rs2D; RdE <= RdD; ImmExtE <= ImmExtD; PCPlus4E <= PCPlus4D;
        lAuiPCE <= lAuiPCD; funct3E <= funct3D;
        PredTakenE <= PredTakenD; PredTargetE <= PredTargetD;
    end
end

endmodule