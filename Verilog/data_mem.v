
// data_mem.v - word-accessible data memory
module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 64) (
    input       clk, reset,
    input [3:0] wea,          // Store operation type
    input       [ADDR_WIDTH-1:0] addr,
    input       [DATA_WIDTH-1:0] wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data
);

// array of 64 32-bit words
reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

// word-aligned address
wire [ADDR_WIDTH-1:0] word_addr = addr[ADDR_WIDTH-1:2] % MEM_SIZE;

always @(posedge clk) begin
    if (|wea) begin  // write only if any byte enable is active
        if (wea[0]) data_ram[word_addr][7:0]   <= wr_data[7:0];
        if (wea[1]) data_ram[word_addr][15:8]  <= wr_data[15:8];
        if (wea[2]) data_ram[word_addr][23:16] <= wr_data[23:16];
        if (wea[3]) data_ram[word_addr][31:24] <= wr_data[31:24];
    end
    rd_data <= data_ram[word_addr]; // read data on every clock edge
end

endmodule