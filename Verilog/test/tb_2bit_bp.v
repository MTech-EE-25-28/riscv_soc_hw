`timescale 1ns/1ps

module tb_2bit_bp;

reg clk, reset;
reg [31:0] pc_fetch, pc_update, target_update;
reg update_en, branch_taken;
wire predict_taken, prediction_valid;
wire [31:0] predicted_target;

// Instantiate DUT
branch_predictor #(
    .BTB_SIZE(16),  // Updated to match optimized module
    .ADDR_WIDTH(32)
) dut (
    .clk(clk),
    .reset(reset),
    .pc_fetch(pc_fetch),
    .predict_taken(predict_taken),
    .predicted_target(predicted_target),
    .prediction_valid(prediction_valid),
    .update_en(update_en),
    .pc_update(pc_update),
    .target_update(target_update),
    .branch_taken(branch_taken)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test stimulus
initial begin
    $dumpfile("./Verilog/dumps/tb_2bit_bp.vcd");
    $dumpvars(0, tb_2bit_bp);

    $display("\n=== Branch Predictor with BTB Test ===\n");

    // Initialize
    reset = 0;
    pc_fetch = 0;
    pc_update = 0;
    target_update = 0;
    update_en = 0;
    branch_taken = 0;
    #10;
    reset = 1;
    #10;

    // Test 1: First branch at 0x100 - not in BTB yet
    $display("Test 1: Cold miss - Branch at 0x100 not in BTB");
    pc_fetch = 32'h0000_0100;
    #10;
    $display("  PC: 0x%h, Valid: %b, Predict Taken: %b",
                pc_fetch, prediction_valid, predict_taken);
    if (!prediction_valid)
        $display("  PASS: Branch not in BTB (cold miss)\n");
    else
        $display("  FAIL: Should not be valid\n");

    // Test 2: Train branch at 0x100 -> 0x200 (taken)
    $display("Test 2: Train branch 0x100 -> 0x200 (taken)");
    pc_update = 32'h0000_0100;
    target_update = 32'h0000_0200;
    branch_taken = 1;
    update_en = 1;
    #10;
    update_en = 0;
    #10;

    // Test 3: Predict same branch - should be valid now
    $display("Test 3: Predict trained branch at 0x100");
    pc_fetch = 32'h0000_0100;
    #10;
    $display("  PC: 0x%h, Valid: %b, Predict: %b, Target: 0x%h",
                pc_fetch, prediction_valid, predict_taken, predicted_target);
    if (prediction_valid && predicted_target == 32'h0000_0200)
        $display("  PASS: Branch found in BTB with correct target\n");
    else
        $display("  FAIL: Should be valid with target 0x200\n");

    // Test 4: Train same branch as taken again (strengthen)
    $display("Test 4: Strengthen prediction (taken again)");
    pc_update = 32'h0000_0100;
    target_update = 32'h0000_0200;
    branch_taken = 1;
    update_en = 1;
    #10;
    update_en = 0;
    #10;

    pc_fetch = 32'h0000_0100;
    #10;
    $display("  Predict Taken: %b (should be strongly taken now)\n", predict_taken);

    // Test 5: Branch not taken once (weaken)
    $display("Test 5: Weaken prediction (not taken once)");
    pc_update = 32'h0000_0100;
    branch_taken = 0;
    update_en = 1;
    #10;
    update_en = 0;
    #10;

    pc_fetch = 32'h0000_0100;
    #10;
    $display("  Predict Taken: %b (should still predict taken - weakly)\n", predict_taken);

    // Test 6: Train different branch at 0x104 -> 0x300
    $display("Test 6: Train different branch at 0x104 -> 0x300");
    pc_update = 32'h0000_0104;
    target_update = 32'h0000_0300;
    branch_taken = 1;
    update_en = 1;
    #10;
    update_en = 0;
    #10;

    pc_fetch = 32'h0000_0104;
    #10;
    $display("  PC: 0x%h, Valid: %b, Target: 0x%h",
                pc_fetch, prediction_valid, predicted_target);
    if (prediction_valid && predicted_target == 32'h0000_0300)
        $display("  PASS: Second branch stored correctly\n");
    else
        $display("  FAIL: Should have target 0x300\n");

    // Test 7: Verify first branch still works
    $display("Test 7: Check first branch still in BTB");
    pc_fetch = 32'h0000_0100;
    #10;
    $display("  PC: 0x%h, Valid: %b, Target: 0x%h",
                pc_fetch, prediction_valid, predicted_target);
    if (prediction_valid && predicted_target == 32'h0000_0200)
        $display("  PASS: First branch still valid\n");
    else
        $display("  FAIL: First branch corrupted\n");

    // Test 8: Train branch to not taken (flip prediction)
    $display("Test 8: Train branch at 0x100 as not taken twice");
    pc_update = 32'h0000_0100;
    branch_taken = 0;
    update_en = 1;
    #10;
    #10;  // Second not-taken update
    update_en = 0;
    #10;

    pc_fetch = 32'h0000_0100;
    #10;
    $display("  Predict Taken: %b (should be NOT taken now)\n", predict_taken);
    if (!predict_taken)
        $display("  PASS: Prediction flipped to not-taken\n");
    else
        $display("  FAIL: Should predict not-taken\n");

    $display("=== All Tests Complete ===\n");
    #50;
    $finish;
end

// Timeout watchdog
initial begin
    #5000;
    $display("ERROR: Testbench timeout!");
    $finish;
end

endmodule
