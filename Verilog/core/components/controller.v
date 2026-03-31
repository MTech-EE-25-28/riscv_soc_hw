
// controller.v - controller for RISC-V CPU
module controller (
    input [11:0] funct12,
    input [6:0]  op,
    input [2:0]  funct3,
    input        funct7b5, funct7b0,
    output [4:0] ALUControl,
    output [1:0] ResultSrc, ImmSrc,
    output       MemWrite, ALUSrc, Branch,
    output       RegWrite, Jump, Jalr, csrSel,
    output       ierr, ecall, ebreak, wfi, ret
);

wire [1:0] ALUOp;

main_decoder    md (funct12, op, funct3, ResultSrc, ImmSrc, ALUOp, MemWrite, Branch,
                    ALUSrc, RegWrite, Jump, Jalr, csrSel, ierr, ecall, ebreak, wfi, ret);

alu_decoder     ad (op[5], funct3, funct7b5, funct7b0, ALUOp, ALUControl);

endmodule