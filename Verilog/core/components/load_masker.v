
// load_masker.v - Memory load masking logic
// Extracts and sign/zero extends bytes and halfwords from word reads
module load_masker #(parameter DATA_WIDTH = 32) (
    input  [2:0]               funct3,      // Load type
    input  [1:0]               byte_offset, // addr[1:0]
    input  [DATA_WIDTH-1:0]    rd_data_in,  // Data from memory (word)
    output reg [DATA_WIDTH-1:0] rd_data_out  // Masked read data to CPU
);

// Load masking - extract and sign/zero extend
always @(*) begin
    case (funct3)
        3'b000: begin // lb (load byte - sign extended)
            case (byte_offset)
                2'b00: rd_data_out = {{24{rd_data_in[7]}},  rd_data_in[7:0]};
                2'b01: rd_data_out = {{24{rd_data_in[15]}}, rd_data_in[15:8]};
                2'b10: rd_data_out = {{24{rd_data_in[23]}}, rd_data_in[23:16]};
                2'b11: rd_data_out = {{24{rd_data_in[31]}}, rd_data_in[31:24]};
            endcase
        end
        3'b001: begin // lh (load halfword - sign extended)
            case (byte_offset[1])
                1'b0: rd_data_out = {{16{rd_data_in[15]}}, rd_data_in[15:0]};
                1'b1: rd_data_out = {{16{rd_data_in[31]}}, rd_data_in[31:16]};
            endcase
        end
        3'b010: rd_data_out = rd_data_in; // lw (load word)
        3'b100: begin // lbu (load byte - zero extended)
            case (byte_offset)
                2'b00: rd_data_out = {24'b0, rd_data_in[7:0]};
                2'b01: rd_data_out = {24'b0, rd_data_in[15:8]};
                2'b10: rd_data_out = {24'b0, rd_data_in[23:16]};
                2'b11: rd_data_out = {24'b0, rd_data_in[31:24]};
            endcase
        end
        3'b101: begin // lhu (load halfword - zero extended)
            case (byte_offset[1])
                1'b0: rd_data_out = {16'b0, rd_data_in[15:0]};
                1'b1: rd_data_out = {16'b0, rd_data_in[31:16]};
            endcase
        end
        default: rd_data_out = rd_data_in;
    endcase
end

endmodule