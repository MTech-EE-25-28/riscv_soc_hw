
// pipeline registers writeback stage
module pl_reg_w (
    input clk, clr, flush,

    input       [1:0] ResultSrcM,
    input             RegWriteM,
    input      [31:0] ALUResultM, ReadData,
    input       [4:0] RdM,
    input      [31:0] PCPlus4M, lAuiPCM, PCM, WriteDataM,
    input       [2:0] funct3M,
    input       [3:0] excDecM,
    input             tretM,
    input             memMisAlignLoadM, memMisAlignStoreM,

    output reg  [1:0] ResultSrcW,
    output reg        RegWriteW,
    output reg [31:0] ALUResultW, ReadDataW,
    output reg  [4:0] RdW,
    output reg [31:0] PCPlus4W, lAuiPCW, PCW, WriteDataW,
    output reg  [2:0] funct3W,
    output reg  [3:0] excDecW,
    output reg        tretW,
    output reg        memMisAlignLoadW, memMisAlignStoreW
);

always @(posedge clk) begin
    if (!clr || flush) begin
        RegWriteW <= 0; ResultSrcW <= 0; ALUResultW <= 0; ReadDataW <= 0;
        excDecW <= 0; tretW <= 0; memMisAlignLoadW <= 0; memMisAlignStoreW <= 0;
        RdW <= 0; PCPlus4W <= 0; lAuiPCW <= 0; PCW <= 0; WriteDataW <= 0; funct3W <= 0;
    end else begin
        RegWriteW <= RegWriteM; ResultSrcW <= ResultSrcM; ALUResultW <= ALUResultM;
        ReadDataW <= ReadData; RdW <= RdM; PCPlus4W <= PCPlus4M; lAuiPCW <= lAuiPCM;
        PCW <= PCM; WriteDataW <= WriteDataM; funct3W <= funct3M; excDecW <= excDecM;
        tretW <= tretM; memMisAlignLoadW <= memMisAlignLoadM; memMisAlignStoreW <= memMisAlignStoreM;
    end
end

endmodule