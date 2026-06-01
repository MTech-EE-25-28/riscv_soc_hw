// black Cell Module
module black_cell(
    input A, B, C, D,
    output E, F
);

assign E = B & D;
assign F = A | (B & C);

endmodule

