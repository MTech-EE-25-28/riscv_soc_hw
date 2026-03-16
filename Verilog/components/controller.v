
// controller.v - controller for RISC-V CPU
module controller (
    input [6:0]  op,
    input [2:0]  funct3,
    input        funct7b5, funct7b0,
    output [1:0] ResultSrc,
    output       MemWrite,
    output       ALUSrc,
    output       RegWrite, Jump, Jalr,
    output [1:0] ImmSrc,
    output [4:0] ALUControl,
    output       Branch
);

wire [1:0] ALUOp;

main_decoder    md (op, funct3, ResultSrc, MemWrite, Branch,
                    ALUSrc, RegWrite, Jump, Jalr, ImmSrc, ALUOp);

alu_decoder     ad (op[5], funct3, funct7b5, funct7b0, ALUOp, ALUControl);

endmodule