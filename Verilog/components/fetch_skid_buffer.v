
// module fetch_skid_buffer
// Description: A skid buffer to hold one fetch packet when decode stage is stalled,
// and drop one stale fetch return after a redirect flush. This keeps the fetch-decode
// interface synchronous and simple, while still allowing the fetch stage to return
// instructions every cycle when the decode stage is stalled.
module fetch_skid_buffer (
    input         clk,
    input         reset,
    input         decode_stall,
    input         decode_flush,
    input  [31:0] imem_instr,
    input  [31:0] fetch_pc,
    input  [31:0] fetch_pcplus4,
    input         pred_taken_in,
    input  [31:0] pred_target_in,
    output        decode_flush_out,
    output [31:0] decode_instr,
    output [31:0] decode_pc,
    output [31:0] decode_pcplus4,
    output        pred_taken_out,
    output [31:0] pred_target_out
);

reg        hold_valid;
reg        drop_next_resp;
reg [31:0] hold_instr;
reg [31:0] hold_pc;
reg [31:0] hold_pcplus4;
reg        hold_pred_taken;
reg [31:0] hold_pred_target;

assign decode_flush_out = decode_flush | drop_next_resp;
assign decode_instr = hold_valid ? hold_instr : imem_instr;
assign decode_pc = hold_valid ? hold_pc : fetch_pc;
assign decode_pcplus4 = hold_valid ? hold_pcplus4 : fetch_pcplus4;
assign pred_taken_out = hold_valid ? hold_pred_taken : pred_taken_in;
assign pred_target_out = hold_valid ? hold_pred_target : pred_target_in;

// Scenario: decode stalls on i2, but synchronous IMEM still returns i3 this cycle.
// Resolution: hold one fetch packet {instr, pc, pc+4, prediction info} and drop
// one stale return after a redirect so instruction and prediction stay aligned.
always @(posedge clk) begin
    if (!reset) begin
        hold_valid <= 1'b0;
        drop_next_resp <= 1'b0;
        hold_instr <= 32'b0;
        hold_pc <= 32'b0;
        hold_pcplus4 <= 32'b0;
        hold_pred_taken <= 1'b0;
        hold_pred_target <= 32'b0;
    end else if (decode_flush) begin
        hold_valid <= 1'b0;
        drop_next_resp <= 1'b1;
    end else begin
        drop_next_resp <= 1'b0;

        if (hold_valid && !decode_stall) begin
            hold_valid <= 1'b0;
        end else if (!hold_valid && decode_stall && !drop_next_resp) begin
            hold_valid <= 1'b1;
            hold_instr <= imem_instr;
            hold_pc <= fetch_pc;
            hold_pcplus4 <= fetch_pcplus4;
            hold_pred_taken <= pred_taken_in;
            hold_pred_target <= pred_target_in;
        end
    end
end

endmodule