`timescale 1ns/1ps

module fifo_sync1 #(
    parameter DATA_WIDTH = 8,        // byte read width
    parameter DEPTH      = 64,       // must be power of 2
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  resetn,

    // Write interface (writes 32-bit word = 4 bytes)
    input  wire                  wr_en,
    input  wire [31:0]           wr_data,
    output wire                  full,

    // Read interface (reads 8-bit byte)
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    // ----------------------------------------
    // Internal byte array
    // ----------------------------------------
    reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];

    // Pointers
    // Using ADDR_WIDTH+1 bits for full/empty
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    // ----------------------------------------
    // EMPTY / FULL logic
    // ----------------------------------------

    assign empty = (wr_ptr == rd_ptr);

    // FIFO full when (wr_ptr + 4) == rd_ptr
    assign full  = ((wr_ptr + 4) == rd_ptr);

    // ----------------------------------------
    // WRITE (32-bit ? 4 bytes)
    // ----------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin

            // Write 4 bytes with wrap-around for power-of-2 depth
            mem[(wr_addr      ) & (DEPTH-1)] <= wr_data[31:24];
            mem[(wr_addr + 1  ) & (DEPTH-1)] <= wr_data[23:16];
            mem[(wr_addr + 2  ) & (DEPTH-1)] <= wr_data[15:8];
            mem[(wr_addr + 3  ) & (DEPTH-1)] <= wr_data[7:0];

            // Move pointer by 4 bytes
            wr_ptr <= wr_ptr + 4;
        end
    end

    // ----------------------------------------
    // READ POINTER (BYTE)
    // ----------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1; // consume 1 byte
        end
    end

    // ----------------------------------------
    // COMBINATIONAL READ (FWFT)
    // ----------------------------------------
    assign rd_data = mem[rd_addr];

endmodule