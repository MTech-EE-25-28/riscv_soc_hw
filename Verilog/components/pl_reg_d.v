
// pipeline registers decode stage
module pl_reg_d (
    input             clk, en, clr,
    input      [31:0] InstrF, PCF, PCPlus4F,
    input             PredTakenF, misAlignF,
    input      [31:0] PredTargetF,
    output reg [31:0] InstrD, PCD, PCPlus4D,
    output reg        PredTakenD, misAlignD,
    output reg [31:0] PredTargetD
);

always @(posedge clk) begin
    if (clr) begin
        InstrD <= 0; PCD <= 0; PCPlus4D <= 0;
        PredTakenD <= 0; PredTargetD <= 0; misAlignD <= 0;
    end else if (!en) begin
        InstrD <= InstrF; PCD <= PCF;
        PCPlus4D <= PCPlus4F; misAlignD <= misAlignF;
        PredTakenD <= PredTakenF; PredTargetD <= PredTargetF;
    end
end

endmodule