`timescale 1ns/1ps

module fifo_sync2 #(
    parameter DATA_WIDTH = 8,        // byte width
    parameter DEPTH      = 64,       // must be power of 2
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  resetn,

    // Write interface (BYTE write)
    input  wire                  wr_en,
    input  wire [DATA_WIDTH -1 :0]           wr_data,   // only wr_data[7:0] used
    output wire                  full,

    // Read interface (WORD read = 4 bytes)
    input  wire                  rd_en,
    output wire [31:0] rd_data,
    output wire                  empty
);

    // ----------------------------------------
    // Internal memory (byte array)
    // ----------------------------------------
    reg [7:0] mem[0:DEPTH-1];

    // Pointers
    reg [ADDR_WIDTH:0] wr_ptr;   // increments by 1 (byte)
    reg [ADDR_WIDTH:0] rd_ptr;   // increments by 4 (word)

    // Addresses for memory indexing
    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    // ----------------------------------------
    // EMPTY / FULL LOGIC
    // ----------------------------------------
    assign empty = (wr_ptr == rd_ptr);

    // FIFO full when advancing wr_ptr by 1 catches rd_ptr
    assign full = ((wr_ptr + 1) == rd_ptr);

    // ----------------------------------------
    // BYTE WRITE
    // ----------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_addr] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // ----------------------------------------
    // WORD READ POINTER (advance by 4)
    // ----------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 4;
        end
    end

    // ----------------------------------------
    // COMBINATIONAL 32-bit READ (4 bytes)
    // Zero padded if insufficient bytes available
    // ----------------------------------------

    wire [ADDR_WIDTH:0] available_bytes = wr_ptr - rd_ptr;

    wire [ADDR_WIDTH-1:0] a0 = rd_addr;
    wire [ADDR_WIDTH-1:0] a1 = (rd_addr + 1) & (DEPTH-1);
    wire [ADDR_WIDTH-1:0] a2 = (rd_addr + 2) & (DEPTH-1);
    wire [ADDR_WIDTH-1:0] a3 = (rd_addr + 3) & (DEPTH-1);

    assign rd_data = {
        (available_bytes > 0 ? mem[a0] : 8'h00),
        (available_bytes > 1 ? mem[a1] : 8'h00),
        (available_bytes > 2 ? mem[a2] : 8'h00),
        (available_bytes > 3 ? mem[a3] : 8'h00)
    };

endmodule