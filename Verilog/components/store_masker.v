
// store_masker.v - Memory store masking and alignment logic
// Generates byte enables and aligns write data for SB, SH, SW operations
module store_masker #(parameter DATA_WIDTH = 32) (
    input  [2:0]               funct3,      // Store type
    input  [1:0]               byte_offset, // addr[1:0]
    input  [DATA_WIDTH-1:0]    wr_data_in,  // Data from register
    output reg [DATA_WIDTH-1:0] wr_data_out, // Aligned data to memory
    output reg [3:0]           wea          // Byte enable signals
);

always @(*) begin
    // Default values
    wr_data_out = 32'b0;
    wea = 4'b0000;

    case (funct3)
        3'b000: begin // sb (store byte)
            case (byte_offset)
                2'b00: begin
                    wr_data_out = {24'b0, wr_data_in[7:0]};
                    wea = 4'b0001;
                end
                2'b01: begin
                    wr_data_out = {16'b0, wr_data_in[7:0], 8'b0};
                    wea = 4'b0010;
                end
                2'b10: begin
                    wr_data_out = {8'b0, wr_data_in[7:0], 16'b0};
                    wea = 4'b0100;
                end
                2'b11: begin
                    wr_data_out = {wr_data_in[7:0], 24'b0};
                    wea = 4'b1000;
                end
            endcase
        end

        3'b001: begin // sh (store halfword)
            case (byte_offset[1])
                1'b0: begin
                    wr_data_out = {16'b0, wr_data_in[15:0]};
                    wea = 4'b0011;
                end
                1'b1: begin
                    wr_data_out = {wr_data_in[15:0], 16'b0};
                    wea = 4'b1100;
                end
            endcase
        end

        3'b010: begin // sw (store word)
            wr_data_out = wr_data_in;
            wea = 4'b1111;
        end

        default: begin
            wr_data_out = 32'b0;
            wea = 4'b0000;
        end
    endcase
end

endmodule
