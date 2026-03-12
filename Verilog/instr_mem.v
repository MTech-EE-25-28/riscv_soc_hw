
// instr_mem.v - Sequential instruction memory
module instr_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 2048) (
    input  clk, reset, wea,
    input  [ADDR_WIDTH-1:0] instr_addr,
    input  [DATA_WIDTH-1:0] instr_in,
    output reg [DATA_WIDTH-1:0] instr
);

// array of 512 32-bit words or instructions
reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];

initial begin
    // add the path from root of the script
    // $readmemh("./Verilog/rv32i_test.hex", instr_ram);
    $readmemh("./docker/bin/factorial.hex", instr_ram);
end

// Sequential read
always @(posedge clk) begin
    if (!reset)
        instr <= 32'h0000_0000;
    else if (wea)
        instr_ram[instr_addr[31:2]] <= instr_in;
    else
        instr <= instr_ram[instr_addr[31:2]];
end

endmodule