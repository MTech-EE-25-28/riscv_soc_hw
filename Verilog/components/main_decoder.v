
// main_decoder.v - logic for main decoder
module main_decoder (
    input  [6:0] op,
    input  [2:0] funct3,
    output [1:0] ResultSrc,
    output       MemWrite, Branch, ALUSrc,
    output       RegWrite, Jump, Jalr, csrSel,
    output [1:0] ImmSrc,
    output [1:0] ALUOp
);

reg [12:0] controls = 13'b0_00_0_0_00_00_0_0_0_0;

always @(*) begin
    casez (op)
        // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_ALUOp_Jump_Jalr_Branch_csrsel
        7'b0000011: controls = 13'b1_00_1_0_01_00_0_0_0_0; // lw
        7'b0100011: controls = 13'b0_01_1_1_00_00_0_0_0_0; // sw
        7'b0110011: controls = 13'b1_xx_0_0_00_10_0_0_0_0; // R–type
        7'b1100011: begin // branch
            controls = 13'b0_10_0_0_xx_01_0_0_1_0; //beq, bne, blt, bge
            case (funct3)
                3'b110: controls = 13'b0_10_0_0_xx_11_0_0_1_0; // bltu
                3'b111: controls = 13'b0_10_0_0_xx_11_0_0_1_0; // bgeu
            endcase
        end
        7'b0010011: controls = 13'b1_00_1_0_00_10_0_0_0_0; // I–type ALU
        7'b1101111: controls = 13'b1_11_0_0_10_00_1_0_0_0; // jal
        7'b1100111: controls = 13'b1_00_1_0_10_00_0_1_0_0; // jalr
        7'b0?10111: controls = 13'b1_xx_x_0_11_xx_0_0_0_0; // lui or auipc
        7'b1110011: controls = 13'b0_xx_x_0_11_xx_0_0_0_1; // csr
        default:    controls = 13'b0_00_0_0_00_00_0_0_0_0; // ???
    endcase
end

assign {RegWrite, ImmSrc, ALUSrc, MemWrite, ResultSrc, ALUOp, Jump, Jalr, Branch, csrSel} = controls;

endmodule