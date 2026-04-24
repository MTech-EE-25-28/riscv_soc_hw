`timescale 1ns / 1ps
// Testbench to verify Machine Timer Interrupt (MTIP) functionality
// Tests the core-level timer interrupt using mtimer_test.hex
module tb_soc_timer;

reg clk, reset;
// APB signals
reg pclk, presetn;
// Debug outputs
wire [31:0] PC, Result, ALUResult, DataAdr, WriteData_M, WriteData, ReadData;
wire        MemWrite, pwm_out0, pwm_out1, pwm_out2;
// peripheral interfaces
wire [31:0] gpio_pad;
wire        tx, rx;
wire [3:0]  qspi_io;
wire        qspi_sck, qspi_cs_n;
wire        cpu_resetn;

assign rx = tx; // UART loopback: tx idles high, so rx never floats

soc dut (
    clk, reset, pclk, presetn,
    PC, Result, ALUResult, DataAdr, WriteData_M, WriteData, ReadData, MemWrite,
    pwm_out0, pwm_out1, pwm_out2, gpio_pad, rx, tx, qspi_io, qspi_sck, qspi_cs_n, cpu_resetn
);

// Clock generation: 50MHz (20ns period)
always #10 clk = ~clk;
always #10 pclk = ~pclk;

// Test variables
integer test_loc_value = 0;
integer prev_test_loc = 0;
integer interrupt_count = 0;
integer first_interrupt_seen = 0;
integer test_passed = 0;

initial begin
    $dumpfile("./Verilog/dumps/tb_soc_timer.vcd");
    $dumpvars(0, tb_soc_timer);

    // Initialize signals
    clk = 0; reset = 0; pclk = 0; presetn = 0;
    $display("\n=== Machine Timer Interrupt Test ===");
    $display("Time: Waiting for reset...");
    #100; // Wait for reset to propagate

    reset = 1; presetn = 1; // Release reset
    $display("Time %0t: Reset released, starting execution", $time);

    // Run for enough time to see multiple timer interrupts
    // Initial interrupt at ~5000 cycles, then every ~10000 cycles
    // At 20ns per cycle, 5000 cycles = 100us, 10000 cycles = 200us
    // Run for ~2ms to see ~10 interrupts
    #2000000;

    // Check test results
    if (interrupt_count >= 5) begin
        $display("\n SUCCESS: Machine Timer Interrupt test PASSED!");
        $display("  - Observed %0d timer interrupts", interrupt_count);
        $display("  - Final TEST_LOC value: %0d", test_loc_value);
        test_passed = 1;
    end else begin
        $display("\n FAILURE: Machine Timer Interrupt test FAILED!");
        $display("  - Only observed %0d interrupts (expected >= 5)", interrupt_count);
        $display("  - Final TEST_LOC value: %0d", test_loc_value);
    end

    $display("\nSimulation finished at time %0t", $time);
    $finish;
end

// Monitor TEST_LOC writes to detect timer interrupts
always @(negedge clk) begin
    if (MemWrite && reset) begin
        if (DataAdr == 32'h00001000) begin
            test_loc_value = WriteData_M;

            // Detect increment (indicating timer interrupt fired)
            if (test_loc_value != prev_test_loc) begin
                interrupt_count = interrupt_count + 1;

                if (interrupt_count == 1) begin
                    $display("Time %0t: First timer interrupt detected! TEST_LOC = %0d",
                             $time, test_loc_value);
                    first_interrupt_seen = 1;
                end else if (interrupt_count <= 10) begin
                    $display("Time %0t: Timer interrupt #%0d detected! TEST_LOC = %0d",
                             $time, interrupt_count, test_loc_value);
                end else if (interrupt_count % 10 == 0) begin
                    $display("Time %0t: Timer interrupt #%0d detected! TEST_LOC = %0d",
                             $time, interrupt_count, test_loc_value);
                end

                prev_test_loc = test_loc_value;
            end
        end
    end
end

// Timeout watchdog for stuck situations
initial begin
    #100000; // Wait 100us before checking for first interrupt
    if (!first_interrupt_seen) begin
        $display("\nWARNING: No timer interrupts detected after 100us");
        // $finish;
    end
end

// Monitor key CSR values (optional debug output)
reg [63:0] prev_cycle_counter = 0;
reg [63:0] prev_timecmp = 0;
always @(posedge clk) begin
    if (reset) begin
        // Sample CSR values periodically for debug
        if ($time % 50000 == 0 && $time > 0) begin
            $display("Time %0t: cycle_counter=%0d, timecmp=%0d, mtip=%b, interrupts=%0d",
                    $time, dut.soc_core.rvpl.dp.csr.cycle_counter,
                    {dut.soc_core.rvpl.dp.csr.timecmp_h, dut.soc_core.rvpl.dp.csr.timecmp_l},
                    dut.soc_core.rvpl.dp.csr.mtip, interrupt_count);
        end
    end
end

endmodule
