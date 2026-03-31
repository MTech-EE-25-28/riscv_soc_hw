
// alu_decoder.v - logic for ALU decoder
module alu_decoder (
    input            opb5,
    input [2:0]      funct3,
    input            funct7b5, funct7b0,
    input [1:0]      ALUOp,
    output reg [4:0] ALUControl
);

initial begin
    ALUControl = 5'b00000;
end

always @(*) begin
    case (ALUOp)
        2'b00: ALUControl = 5'b00000; // addition
        2'b01: ALUControl = 5'b00001; // subtraction
        2'b11: ALUControl = 5'b00100; // branch if greater than or equal unsigned using sltu
        2'b10:
            case (funct3) // R-type or I-type ALU
                3'b000: begin
                    // True for R-type subtract
                    if (funct7b5 & opb5) ALUControl = 5'b00001; //sub
                    else if (funct7b0 & opb5) ALUControl = 5'b10000; // mul
                    else ALUControl = 5'b00000; // add, addi
                end
                3'b001:  begin
                    if (funct7b0 & opb5) ALUControl = 5'b10001; // mulh
                    else ALUControl = 5'b00010; // sll, slli
                end
                3'b010: begin
                    if (funct7b0 & opb5) ALUControl = 5'b10010; // mulhsu
                    else ALUControl = 5'b00011; // slt, slti
                end
                3'b011: begin
                    if (funct7b0 & opb5) ALUControl = 5'b10011; // mulhu
                    else ALUControl = 5'b00100; // stlu, sltiu
                end
                3'b100: begin
                    if (funct7b0 & opb5) ALUControl = 5'b11100; // div
                    else ALUControl = 5'b00101; // xor, xori
                end
                3'b101: begin
                    if (funct7b0 & opb5) ALUControl = 5'b11101; // divu
                    else begin
                        case (funct7b5)
                            0: ALUControl = 5'b00110; // srl, srli
                            1: ALUControl = 5'b00111; // sra, srai
                        endcase
                    end
                end
                3'b110: begin
                    if (funct7b0 & opb5) ALUControl = 5'b11110; // rem
                    else ALUControl = 5'b01000; // or, ori
                end
                3'b111: begin
                    if (funct7b0 & opb5) ALUControl = 5'b11111; // remu
                    else ALUControl = 5'b01001; // and, andi
                end
                default: ALUControl = 5'b0xxxx; // ???
            endcase
        default: ALUControl = 5'b0xxxx;
    endcase
end

endmodule