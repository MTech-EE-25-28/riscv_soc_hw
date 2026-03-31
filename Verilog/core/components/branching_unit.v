
// branching_unit.v - logic for branching in execute stage
module branching_unit (
    input [2:0] funct3,
    input       Zero, ALUR31,
    output reg  Branch
);

always @(*) begin
    Branch = 0;
    case (funct3)
        3'b000: Branch =    Zero; // beq
        3'b001: Branch =   !Zero; // bne
        3'b100: Branch =  ALUR31; // blt
        3'b101: Branch = !ALUR31; // bge
        3'b110: Branch =   !Zero; // bltu
        3'b111: Branch =    Zero; // bgeu
    endcase
end

endmodule