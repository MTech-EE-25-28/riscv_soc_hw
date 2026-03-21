
// pipeline registers memory stage

module pl_reg_m (
    input clk, clr, stall,

    input   [1:0] ResultSrcE,
    input         MemWriteE, RegWriteE,
    input  [31:0] ALUResultE, WriteDataE,
    input   [4:0] RdE,
    input  [31:0] PCPlus4E, lAuiPCE,
    input   [2:0] funct3E,
    input  [31:0] PCE,
    input         BranchE, BranchTakenE,
    input  [31:0] PCTargetE,

    output reg  [1:0] ResultSrcM,
    output reg        MemWriteM, RegWriteM,
    output reg [31:0] ALUResultM, WriteDataM,
    output reg  [4:0] RdM,
    output reg [31:0] PCPlus4M, lAuiPCM,
    output reg  [2:0] funct3M,
    output reg [31:0] PCM,
    output reg        BranchM, BranchTakenM,
    output reg [31:0] PCTargetM
);

always @(posedge clk) begin
    if (!clr) begin
        RegWriteM <= 0; ResultSrcM <= 0; MemWriteM <= 0; ALUResultM <= 0;
        WriteDataM <= 0; RdM <= 0; PCPlus4M <= 0; lAuiPCM <= 0; funct3M <= 0; PCM <= 0;
        BranchM <= 0; BranchTakenM <= 0; PCTargetM <= 0;
    end else if (!stall) begin
        RegWriteM <= RegWriteE; ResultSrcM <= ResultSrcE; MemWriteM <= MemWriteE;
        ALUResultM <= ALUResultE; WriteDataM <= WriteDataE; RdM <= RdE;
        PCPlus4M <= PCPlus4E; lAuiPCM <= lAuiPCE; funct3M <= funct3E; PCM <= PCE;
        BranchM <= BranchE; BranchTakenM <= BranchTakenE; PCTargetM <= PCTargetE;
    end
end

endmodule
