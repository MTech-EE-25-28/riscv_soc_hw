
// data_mem.v - word-accessible data memory
module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 2048) (
    input       clk,
    input [3:0] wea,
    input       [ADDR_WIDTH-1:0] addr,
    input       [DATA_WIDTH-1:0] wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data
);

// array of 32-bit words
reg [DATA_WIDTH/4-1:0] data_ram0 [0:MEM_SIZE-1];
reg [DATA_WIDTH/4-1:0] data_ram1 [0:MEM_SIZE-1];
reg [DATA_WIDTH/4-1:0] data_ram2 [0:MEM_SIZE-1];
reg [DATA_WIDTH/4-1:0] data_ram3 [0:MEM_SIZE-1];

// Load .data section initial values from the same hex file used by instr_mem.
// .data VMA=LMA=0x1000, so it appears at word offset 0x400 in the hex file.
reg [DATA_WIDTH-1:0] init_mem [0:MEM_SIZE-1];
initial begin
    string hex_file;
    integer i;
    if (!$value$plusargs("HEX=%s", hex_file))
        hex_file = "./docker/bin/sw_matrix_mul.hex";
    $readmemh(hex_file, init_mem);
    for (i = 0; i < MEM_SIZE; i = i + 1) begin
        data_ram0[i] = init_mem[i][7:0];
        data_ram1[i] = init_mem[i][15:8];
        data_ram2[i] = init_mem[i][23:16];
        data_ram3[i] = init_mem[i][31:24];
    end
end

// word-aligned address
wire [ADDR_WIDTH-1:0] word_addr = addr[ADDR_WIDTH-1:2];

always @(posedge clk) begin
    rd_data <= {data_ram3[word_addr], data_ram2[word_addr], data_ram1[word_addr], data_ram0[word_addr]};
    if (|wea) begin  // write only if any byte enable is active
        if (wea[0]) data_ram0[word_addr] <= wr_data[7:0];
        if (wea[1]) data_ram1[word_addr] <= wr_data[15:8];
        if (wea[2]) data_ram2[word_addr] <= wr_data[23:16];
        if (wea[3]) data_ram3[word_addr] <= wr_data[31:24];
    end
end

endmodule