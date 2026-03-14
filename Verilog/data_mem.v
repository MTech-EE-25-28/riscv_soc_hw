
// data_mem.v - word-accessible data memory
module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 2048) (
    input       clk, reset,
    input [3:0] wea,          // Store operation type
    input       [ADDR_WIDTH-1:0] addr,
    input       [DATA_WIDTH-1:0] wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data
);

// array of 1024 32-bit words
reg [DATA_WIDTH/4-1:0] data_ram0 [0:MEM_SIZE-1];
reg [DATA_WIDTH/4-1:0] data_ram1 [0:MEM_SIZE-1];
reg [DATA_WIDTH/4-1:0] data_ram2 [0:MEM_SIZE-1];
reg [DATA_WIDTH/4-1:0] data_ram3 [0:MEM_SIZE-1];

// word-aligned address
wire [ADDR_WIDTH-1:0] word_addr = addr[ADDR_WIDTH-1:2];

always @(posedge clk) begin
    if (!reset) rd_data <= 32'h0000_0000;
    else begin
        rd_data <= {data_ram3[word_addr], data_ram2[word_addr], data_ram1[word_addr], data_ram0[word_addr]};
        if (|wea) begin  // write only if any byte enable is active
            if (wea[0]) data_ram0[word_addr] <= wr_data[7:0];
            if (wea[1]) data_ram1[word_addr] <= wr_data[15:8];
            if (wea[2]) data_ram2[word_addr] <= wr_data[23:16];
            if (wea[3]) data_ram3[word_addr] <= wr_data[31:24];
        end
    end
end

endmodule