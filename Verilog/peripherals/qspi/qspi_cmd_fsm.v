`timescale 1ns/1ps

module qspi_cmd_fsm #(
    parameter OPCODE_BITS = 8,
    parameter ADDR_BITS   = 24,
    parameter DATA_BITS   = 8
)(
    input  wire        clk,
    input  wire        resetn,

    // CSR interface
    input  wire        start,
    input  wire [7:0]  csr_opcode,
    input  wire [23:0] csr_addr,
    input  wire [15:0] csr_length,

    // FIFO interfaces
    input  wire        txfifo_empty,
    input  wire [7:0]  txfifo_rdata,
    output reg         txfifo_rd,

    input  wire        rxfifo_full,
    output reg         rxfifo_wr,
    output reg [7:0]   rxfifo_wdata,

    // Shifter interface
    input  wire        shifter_busy,
    input  wire        shifter_done,
    input  wire [7:0]  shifter_rxbyte,
    input wire shifter_data_req,
    input wire shifter_data_ready,
    output reg         shifter_dir,      
    output reg         load_chunk,
    output reg [31:0]  chunk_data,
    output reg [5:0]   chunk_cycles,
    output reg fsm_quad,
    // Chip select (FSM controls)
    output reg         cs_n,

    // Status
    output reg         busy,
    output reg         done
);

    // ------------------------------------------------------------
    // State encodings
    // ------------------------------------------------------------
    localparam IDLE        = 3'd0;
    localparam SEND_OPCODE = 3'd1;
    localparam SEND_ADDR   = 3'd2;
    localparam STREAM_TX   = 3'd3;
    localparam STREAM_RX   = 3'd4;
    localparam DONE_STATE  = 3'd5;
    localparam DUMMY       = 3'd6;

    reg [2:0] cur, next;
    reg [15:0] byte_count;

    // ------------------------------------------------------------
    // Sequential
    // ------------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cur        <= IDLE;
            byte_count <= 0;
        end else begin
            cur <= next;

            if ((cur == STREAM_RX  && shifter_data_ready) || (cur == STREAM_TX && shifter_data_req))
                byte_count <= byte_count - 1;

            if (cur == IDLE && start)
                if (csr_opcode == 8'h05 || csr_opcode == 8'h15 || csr_opcode == 8'h35)
                byte_count <= 15'd1;
                else if (csr_opcode == 8'h01 || csr_opcode == 8'h11 || csr_opcode == 8'h31) 
                byte_count <= 15'd1;
                else if (csr_opcode == 8'h9F)
                byte_count <= 15'd3;
                else 
                byte_count <= csr_length;
                
        end
    end

    // ------------------------------------------------------------
    // Combinational
    // ------------------------------------------------------------
    always @(*) begin
        next         = cur;
        cs_n         = 1'b1;
        busy         = (cur != IDLE);
        done         = 0;
        fsm_quad = 0;
        shifter_dir  = 0;
        load_chunk   = 0;
        chunk_cycles = 0;
        chunk_data   = 8'd0;

        txfifo_rd  = 0;
        rxfifo_wr  = 0;
        rxfifo_wdata = 8'd0;

        case (cur)

            // ====================================================
            IDLE:
            // ====================================================
            begin
                if (start)
                    next = SEND_OPCODE;
            end

            // ====================================================
            SEND_OPCODE:
            // ====================================================
            begin
                cs_n = 1'b0;

                if (!shifter_busy & !shifter_done) begin
                    load_chunk   = 1;
                    chunk_data   = {csr_opcode,24'd0};
                    chunk_cycles = OPCODE_BITS;
                end

                if (shifter_done)
                    case (csr_opcode) 
                    8'h06 : next = DONE_STATE;
                    8'h9F : next = STREAM_RX;
                     8'h6B : next = SEND_ADDR;
                      8'h32 : next = SEND_ADDR;
                       8'h05 : next = STREAM_RX;
                        default next = IDLE;
                         endcase
            end

            // ====================================================
            SEND_ADDR:
            // ====================================================
            begin
                cs_n = 1'b0;
                if (!shifter_busy & !shifter_done) begin
                    load_chunk   = 1;
                    chunk_data   = {csr_addr,8'd0};
                    chunk_cycles = ADDR_BITS;
                end

                if (shifter_done) begin
                    if ( csr_opcode == 8'h6B) next = DUMMY;
                    else next = STREAM_TX;
                end
            end
            
            DUMMY: begin
                cs_n = 1'b0;
                if (!shifter_busy & !shifter_done) begin
                    load_chunk   = 1;
                    chunk_data   = 32'd0;
                    chunk_cycles = 8;
                end
                if (shifter_done) next = STREAM_RX;
             end  
            // ====================================================
            STREAM_TX:
            // ====================================================
            begin
                if(csr_opcode == 8'h6b || csr_opcode ==8'h32) fsm_quad =1;
                cs_n = 1'b0;
                shifter_dir = 0;

                if (!shifter_busy && !txfifo_empty) begin
                    txfifo_rd  = 1;

                    load_chunk   = 1;
                    chunk_data   = {txfifo_rdata ,24'd0};
                    chunk_cycles = 2;
                end

                if (shifter_done && byte_count == 1)
                    next = DONE_STATE;
            end

            // ====================================================
            STREAM_RX:
            // ====================================================
            begin
                cs_n = 1'b0;
                shifter_dir = 1;
                if(csr_opcode == 8'h6b || csr_opcode ==8'h32) fsm_quad =1;
                if (!shifter_busy && !shifter_done) begin
                    load_chunk   = 1;
                    chunk_data   = 32'h00_000000;
                    chunk_cycles = (csr_opcode != 8'h6b && csr_opcode !=8'h32)  ? (byte_count<<3) : (byte_count<< 1) ;
                end

                if (shifter_done && !rxfifo_full) begin
                    rxfifo_wr  = 1;
                    rxfifo_wdata = shifter_rxbyte;

                    if (byte_count == 0)
                        next = DONE_STATE;
                end
            end

            // ====================================================
            DONE_STATE:
            // ====================================================
            begin
                cs_n = 1'b1;
                done = 1;
                next = IDLE;
            end

        endcase
    end

endmodule