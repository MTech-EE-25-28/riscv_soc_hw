
// pipeline registers decode stage
module pl_reg_d (
    input             clk, en, clr,
    input      [31:0] InstrF, PCF, PCPlus4F,
    output reg [31:0] InstrD, PCD, PCPlus4D
);

always @(posedge clk) begin
    if (clr) begin
        InstrD <= 0; PCD <= 0; PCPlus4D <= 0;
    end else if (!en) begin
        InstrD <= InstrF; PCD <= PCF;
        PCPlus4D <= PCPlus4F;
    end
end

endmodule