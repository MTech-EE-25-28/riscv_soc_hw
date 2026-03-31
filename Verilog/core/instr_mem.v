
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
    // add the path from execution directory to the .hex file
    // $readmemh("/home/user/projects/docker/bin/matrix_mul.hex", instr_ram);
    // $readmemh("./docker/bin/rv32i_test.hex", instr_ram);
    $readmemh("./docker/bin/interrupt.hex", instr_ram);
end

// Sequential write
always @(posedge clk) begin
    if (wea)
        instr_ram[instr_addr[31:2]] <= instr_in;
end

// combinational read
assign instr = instr_ram[instr_addr[31:2]];

endmodule