
// data_mem.v - word-accessible data memory
module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 2048) (
    input       clk,
    input [3:0] wea,
    input       [ADDR_WIDTH-1:0] addr,
    input       [DATA_WIDTH-1:0] wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data
);

// Single 32-bit wide array — $readmemh must target the inferred BRAM array
// directly for Vivado to embed init data into the bitstream.
// The byte-split + copy-loop pattern works in simulation but leaves the BRAM
// uninitialized in hardware because Vivado cannot trace through the copy loop.
reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

initial begin
    string hex_file;
    if (!$value$plusargs("HEX=%s", hex_file))
        hex_file = "./docker/bin/sw_matrix_mul.hex";
    $readmemh(hex_file, data_ram);
end

// word-aligned address
wire [ADDR_WIDTH-1:0] word_addr = addr[ADDR_WIDTH-1:2];

always @(posedge clk) begin
    rd_data <= data_ram[word_addr];
    if (|wea) begin  // write only if any byte enable is active
        if (wea[0]) data_ram[word_addr][7:0]   <= wr_data[7:0];
        if (wea[1]) data_ram[word_addr][15:8]  <= wr_data[15:8];
        if (wea[2]) data_ram[word_addr][23:16] <= wr_data[23:16];
        if (wea[3]) data_ram[word_addr][31:24] <= wr_data[31:24];
    end
end

endmodule