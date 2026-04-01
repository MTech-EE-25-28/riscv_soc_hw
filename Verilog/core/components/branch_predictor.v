
// Branch Predictor with BTB (Branch Target Buffer)
module branch_predictor #(
    parameter ADDR_WIDTH = 32,
    parameter BTB_SIZE = 8,
    parameter TAG_WIDTH = 8 // for better timing, its uC as well
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [ADDR_WIDTH-1:0] pc_fetch,
    output wire predict_taken,
    output wire [ADDR_WIDTH-1:0] predicted_target,
    output wire prediction_valid,
    input wire update_en,
    input wire [ADDR_WIDTH-1:0] pc_update,
    input wire [ADDR_WIDTH-1:0] target_update,
    input wire branch_taken
);

localparam [1:0] ST_NTAKEN = 2'b10,
                 WK_NTAKEN = 2'b11,
                 WK_TAKEN  = 2'b00,
                 ST_TAKEN  = 2'b01;

localparam INDEX_WIDTH = $clog2(BTB_SIZE);

reg [ADDR_WIDTH-1:0] btb_targets [0:BTB_SIZE-1];
reg [1:0]            btb_counters [0:BTB_SIZE-1]; // 2-bit saturating counters
reg [TAG_WIDTH-1:0] btb_tags [0:BTB_SIZE-1]; // PC tags for matching
reg btb_valid [0:BTB_SIZE-1];

// Index generation (use lower bits of PC, excluding byte offset)
wire [INDEX_WIDTH-1:0] fetch_index = pc_fetch[INDEX_WIDTH+1:2];
wire [INDEX_WIDTH-1:0] update_index = pc_update[INDEX_WIDTH+1:2];

// Tag generation (upper bits of PC)
wire [TAG_WIDTH-1:0] fetch_tag = pc_fetch[TAG_WIDTH+INDEX_WIDTH+1:INDEX_WIDTH+2];
wire [TAG_WIDTH-1:0] update_tag = pc_update[TAG_WIDTH+INDEX_WIDTH+1:INDEX_WIDTH+2];

// Prediction Logic
wire tag_match = btb_valid[fetch_index] && (btb_tags[fetch_index] == fetch_tag);
wire [1:0] counter_val = btb_counters[fetch_index];

assign prediction_valid = enable && reset && tag_match;
assign predict_taken    = enable && reset && tag_match && (counter_val[1] == 1'b0);
assign predicted_target = (enable && reset && tag_match) ? btb_targets[fetch_index] : 32'h0;

integer i; // simulation purpose only

always @(posedge clk) begin
    if (!reset) begin
        for (i = 0; i < BTB_SIZE; i = i + 1) begin
            btb_valid[i]    <= 1'b0;
            btb_counters[i] <= WK_TAKEN;
            btb_targets[i]  <= 0;
            btb_tags[i]     <= 0;
        end
    end else if (update_en) begin
        // Update the BTB entry
        btb_valid[update_index] <= 1'b1;
        btb_tags[update_index] <= update_tag;
        btb_targets[update_index] <= target_update;

        // Update 2-bit saturating counter
        case (btb_counters[update_index])
            ST_NTAKEN: btb_counters[update_index] <= branch_taken ? WK_NTAKEN : ST_NTAKEN;
            WK_NTAKEN: btb_counters[update_index] <= branch_taken ? WK_TAKEN  : ST_NTAKEN;
            WK_TAKEN:  btb_counters[update_index] <= branch_taken ? ST_TAKEN  : WK_NTAKEN;
            ST_TAKEN:  btb_counters[update_index] <= branch_taken ? ST_TAKEN  : WK_TAKEN;
        endcase
    end
end

endmodule