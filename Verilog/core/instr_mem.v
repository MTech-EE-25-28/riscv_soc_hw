
// instr_mem.v - Sequential instruction memory
module instr_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 2048) (
    input  clk, wea,
    input  [ADDR_WIDTH-1:0] instr_addr,
    input  [DATA_WIDTH-1:0] instr_in,
    output [DATA_WIDTH-1:0] instr
);

// array of 32-bit instructions
reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];

initial begin
    // Hex file is supplied at runtime via +HEX=<path> plusarg.
    // Fallback: soc_test.hex (used by tb_soc).
    // string hex_file;
    // if (!$value$plusargs("HEX=%s", hex_file))
    //     hex_file = "./docker/bin/soc_test.hex";
    // $readmemh(hex_file, instr_ram);
end

// Sequential write
always @(posedge clk) begin
    if (wea)
        instr_ram[instr_addr[31:2]] <= instr_in;
end

// combinational read
assign instr = instr_ram[instr_addr[31:2]];

endmodule