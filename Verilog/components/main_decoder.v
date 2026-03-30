
// main_decoder.v - logic for main decoder
module main_decoder (
    input [11:0] funct12,
    input  [6:0] op,
    input  [2:0] funct3,
    output [1:0] ResultSrc, ImmSrc, ALUOp,
    output       MemWrite, Branch, ALUSrc,
    output       RegWrite, Jump, Jalr, csrSel,
    output       ierr, ecall, ebreak, wfi, ret
);

reg [17:0] controls = 18'b0_00_0_0_00_00_0_0_0_0_0_0_0_0_0;

always @(*) begin
    casez (op)
        // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_ALUOp_Jump_Jalr_Branch_csrsel_ierr_ecall_ebreak_wfi_ret
        7'b0000000: controls = 18'b0_00_0_0_00_00_0_0_0_0_0_0_0_0_0; // all-zero bubble (flush value) — NOP
        7'b0000011: controls = 18'b1_00_1_0_01_00_0_0_0_0_0_0_0_0_0; // lw
        7'b0100011: controls = 18'b0_01_1_1_00_00_0_0_0_0_0_0_0_0_0; // sw
        7'b0110011: controls = 18'b1_xx_0_0_00_10_0_0_0_0_0_0_0_0_0; // R–type
        7'b1100011: begin // branch
            controls = 18'b0_10_0_0_xx_01_0_0_1_0_0_0_0_0_0; //beq, bne, blt, bge
            case (funct3)
                3'b110: controls = 18'b0_10_0_0_xx_11_0_0_1_0_0_0_0_0_0; // bltu
                3'b111: controls = 18'b0_10_0_0_xx_11_0_0_1_0_0_0_0_0_0; // bgeu
            endcase
        end
        7'b0010011: controls = 18'b1_00_1_0_00_10_0_0_0_0_0_0_0_0_0; // I–type ALU
        7'b1101111: controls = 18'b1_11_0_0_10_00_1_0_0_0_0_0_0_0_0; // jal
        7'b1100111: controls = 18'b1_00_1_0_10_00_0_1_0_0_0_0_0_0_0; // jalr
        7'b0?10111: controls = 18'b1_xx_x_0_11_xx_0_0_0_0_0_0_0_0_0; // lui or auipc
        7'b1110011: begin
            controls = 18'b1_xx_x_0_00_xx_0_0_0_1_0_0_0_0_0; // csr
            if (funct3 == 3'b000) begin
                if (funct12 == 12'b0) controls = 18'b0_00_0_0_00_00_0_0_0_1_0_1_0_0_0; // ecall
                else if (funct12 == 12'b1) controls = 18'b0_00_0_0_00_00_0_0_0_1_0_0_1_0_0; // ebreak
                else if (funct12 == 12'h105) controls = 18'b0_00_0_0_00_00_0_0_0_1_0_0_0_1_0; // wfi
                else if (funct12 == 12'h302) controls = 18'b0_00_0_0_00_00_0_0_0_1_0_0_0_0_1; // mret
            end
        end
        default: controls = 18'b0_00_0_0_00_00_0_0_0_0_1_0_0_0_0; // ???
    endcase
end

assign {RegWrite, ImmSrc, ALUSrc, MemWrite, ResultSrc, ALUOp, Jump, Jalr, Branch, csrSel, ierr, ecall, ebreak, wfi, ret} = controls;

endmodule