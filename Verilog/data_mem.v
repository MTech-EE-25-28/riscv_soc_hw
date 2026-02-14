
// data_mem.v - word-accessible data memory with write masking
module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 64) (
    input       clk, reset,
    input       wr_en,
    input [2:0] funct3,          // Store operation type
    input       [ADDR_WIDTH-1:0] addr,
    input       [DATA_WIDTH-1:0] wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data
);

// array of 64 32-bit words
reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

// word-aligned address
wire [ADDR_WIDTH-1:0] word_addr = addr[ADDR_WIDTH-1:2] % MEM_SIZE;
wire [1:0] byte_offset = addr[1:0];

// Generate write mask and masked data
reg [31:0] write_mask;
reg [31:0] masked_wr_data;

always @(*) begin
    case (funct3)
        3'b000: begin // sb (store byte)
            case (byte_offset)
                2'b00: begin
                    write_mask = 32'h000000FF;
                    masked_wr_data = {24'b0, wr_data[7:0]};
                end
                2'b01: begin
                    write_mask = 32'h0000FF00;
                    masked_wr_data = {16'b0, wr_data[7:0], 8'b0};
                end
                2'b10: begin
                    write_mask = 32'h00FF0000;
                    masked_wr_data = {8'b0, wr_data[7:0], 16'b0};
                end
                2'b11: begin
                    write_mask = 32'hFF000000;
                    masked_wr_data = {wr_data[7:0], 24'b0};
                end
            endcase
        end
        3'b001: begin // sh (store halfword)
            case (byte_offset[1])
                1'b0: begin
                    write_mask = 32'h0000FFFF;
                    masked_wr_data = {16'b0, wr_data[15:0]};
                end
                1'b1: begin
                    write_mask = 32'hFFFF0000;
                    masked_wr_data = {wr_data[15:0], 16'b0};
                end
            endcase
        end
        3'b010: begin // sw (store word)
            write_mask = 32'hFFFFFFFF;
            masked_wr_data = wr_data;
        end
        default: begin
            write_mask = 32'hFFFFFFFF;
            masked_wr_data = wr_data;
        end
    endcase
end

// synchronous write with full 32-bit masked write
always @(posedge clk) begin
    if (wr_en) begin
        data_ram[word_addr] <= (data_ram[word_addr] & ~write_mask) | (masked_wr_data & write_mask);
    end
end

// asynchronous read - full word
always @(*) begin
    rd_data = data_ram[word_addr];
end

endmodule