`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.04.2026 17:47:33
// Design Name: 
// Module Name: UART_module_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module UART_module_tb;

    // --- Signals ---
    reg clk, reset, rx;
    wire tx;
    reg [15:0] BRR_in; reg BRR_en;
    reg [7:0] CR_in;   reg CR_en;
    reg [8:0] TDR_in;  reg TDR_en;
    reg RDR_ren;
    wire [7:0] SR_out; wire [8:0] RDR_out;

    // Status Register Bit Mapping for Readability
    wire NE_flag   = SR_out[7];
    wire FE_flag   = SR_out[6];
    wire PE_flag   = SR_out[5];
    wire OWE_flag  = SR_out[4];
    wire IDLE_flag = SR_out[3];
    wire RXNE_flag = SR_out[1];

    // --- UUT Instantiation ---
    UART_module uut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx),
        .BRR_in(BRR_in),
        .BRR_en(BRR_en),
        .CR_in(CR_in),
        .CR_en(CR_en),
        .TDR_in(TDR_in),
        .TDR_en(TDR_en),
        .RDR_ren(RDR_ren),
        .SR_out(SR_out),
        .RDR_out(RDR_out)
    );
    // --- Clock (100MHz) ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Main Sequence ---
    initial begin
        // 1. Reset
        reset = 1; rx = 1; BRR_in = 0; BRR_en = 0; CR_in = 0; CR_en = 0; TDR_in = 0; TDR_en = 0; RDR_ren = 0;
        #100 reset = 0; #50;

        // Base config: BRR=10 (1 tick = 100ns, 1 bit = 1600ns)
        @(posedge clk); BRR_in = 16'd10; BRR_en = 1; 
        @(posedge clk); BRR_en = 0;

        $display("========================================");
        $display("   UART EDGE CASE STRESS TEST SUITE");
        $display("========================================");

        // ---------------------------------------------------------
        // TEST 1: M=0 (8-bit), PCE=0 (No Parity)
        // ---------------------------------------------------------
        $display("\n[TEST 1] 8-Bit, No Parity (Clean Frame)");
        config_CR1(1, 1, 1, 0, 0, 0); // UE=1, TE=1, RE=1, M=0, PCE=0, PS=0
        send_custom_frame(9'h055, 0, 0, 0, 0, 0, 0); // Data 0x55
        wait(RXNE_flag);
        if (RDR_out == 9'h055 && !NE_flag && !FE_flag && !PE_flag) $display(" -> PASS"); else $display(" -> FAIL");
        clear_rdr();

        // ---------------------------------------------------------
        // TEST 2: M=1 (9-bit), PCE=1, PS=1 (Odd Parity)
        // ---------------------------------------------------------
        $display("\n[TEST 2] 9-Bit, Odd Parity (Clean Frame)");
        config_CR1(1, 1, 1, 1, 1, 1); // M=1, PCE=1, PS=1
        // Data 0x1AA (1 1010 1010 -> 5 ones). Odd Parity should be 0.
        send_custom_frame(9'h1AA, 1, 1, 1, 0, 0, 0); 
        wait(RXNE_flag);
        if (RDR_out == 9'h1AA && !PE_flag) $display(" -> PASS"); else $display(" -> FAIL");
        clear_rdr();

        // ---------------------------------------------------------
        // TEST 3: Parity Error Injection (PE)
        // ---------------------------------------------------------
        $display("\n[TEST 3] Injecting Parity Error (M=0, Even Parity)");
        config_CR1(1, 1, 1, 0, 1, 0); // M=0, PCE=1, PS=0
        // Data 0x33 (4 ones -> Even parity is 0). Injecting PE flips it to 1.
        send_custom_frame(9'h033, 0, 1, 0, 1 /*Inject PE*/, 0, 0); 
        wait(RXNE_flag);
        if (PE_flag) $display(" -> PASS: Parity Error Detected!"); else $display(" -> FAIL: No PE flag");
        clear_rdr();

        // ---------------------------------------------------------
        // TEST 4: Frame Error Injection (FE)
        // ---------------------------------------------------------
        $display("\n[TEST 4] Injecting Frame Error (Bad Stop Bit)");
        send_custom_frame(9'h0F0, 0, 1, 0, 0, 1 /*Inject FE*/, 0); 
        wait(RXNE_flag);
        if (FE_flag) $display(" -> PASS: Frame Error Detected!"); else $display(" -> FAIL: No FE flag");
        clear_rdr();

        // ---------------------------------------------------------
        // TEST 5: Noise Error Injection (NE) & Majority Vote Test
        // ---------------------------------------------------------
        $display("\n[TEST 5] Injecting Noise Error (Mid-bit Glitch)");
        // The task will flip the line specifically at tick #7 of data bit 4.
        // It should flag NE=1, but STILL read the correct data due to majority voting!
        send_custom_frame(9'h0A5, 0, 1, 0, 0, 0, 1 /*Inject NE*/); 
        wait(RXNE_flag);
        if (NE_flag && RDR_out == 9'h0A5) 
            $display(" -> PASS: Noise Flag set AND Data was recovered correctly!"); 
        else $display(" -> FAIL: NE=%b, Data=%h", NE_flag, RDR_out);
        clear_rdr();

        // ---------------------------------------------------------
        // TEST 6: Overrun / Overwrite Error (OWE)
        // ---------------------------------------------------------
        $display("\n[TEST 6] Triggering Overrun Error (OWE)");
        $display(" -> Sending First Byte (0x11)... Not reading RDR.");
        send_custom_frame(9'h011, 0, 1, 0, 0, 0, 0); 
        wait(RXNE_flag);
        #100; // Intentionally NOT calling clear_rdr()
        
        $display(" -> Sending Second Byte (0x22)...");
        send_custom_frame(9'h022, 0, 1, 0, 0, 0, 0); 
        wait(RXNE_flag); // Wait for second frame to finish
        @(posedge clk);  // Wait one tick for flags to settle
        if (OWE_flag) $display(" -> PASS: Overrun Error Detected!"); else $display(" -> FAIL: No OWE flag");
        clear_rdr();

        // ---------------------------------------------------------
        // TEST 7: Idle Flag Check
        // ---------------------------------------------------------
        $display("\n[TEST 7] Waiting for Idle Flag");
        // Frame finished, RX is high. Needs 10 bits of idle time (160 ticks = 16000 ns).
        #17000; 
        if (IDLE_flag) $display(" -> PASS: Idle Flag Detected!"); else $display(" -> FAIL: No IDLE flag");

        $display("\n========================================");
        $display("   ALL EDGE CASE TESTS COMPLETED");
        $display("========================================\n");
        $finish;
    end

    // --- Helper Task: Clear RDR ---
    task clear_rdr;
        begin
            @(posedge clk); RDR_ren = 1;
            @(posedge clk); RDR_ren = 0;
            #100;
        end
    endtask

    // --- Helper Task: Configure CR1 ---
    task config_CR1(input ue, te, re, m, pce, ps);
        begin
            @(posedge clk);
            CR_in = {1'b0, 1'b0, ps, pce, m, re, te, ue};
            CR_en = 1;
            @(posedge clk); CR_en = 0;
        end
    endtask

    // --- Helper Task: Dynamic Frame Generator ---
    task send_custom_frame(
        input [8:0] data, 
        input m_val, input pce_val, input ps_val, 
        input inj_pe, input inj_fe, input inj_ne
    );
        integer limit, i;
        reg calc_p;
        begin
            limit = m_val ? 9 : 8;
            calc_p = ps_val ^ (^data[7:0]); // Calculate expected parity

            rx = 0; #1600; // Start bit (16 ticks)

            for(i=0; i<limit; i=i+1) begin
                if (inj_ne && i == 4) begin
                    // Inject a fast 1-tick glitch at the 7th tick to trigger majority voter
                    rx = data[i];  #700; 
                    rx = ~data[i]; #100; 
                    rx = data[i];  #800; 
                end else begin
                    rx = data[i]; #1600;
                end
            end

            if (pce_val) begin
                rx = inj_pe ? ~calc_p : calc_p; // Send bad parity if injected
                #1600;
            end

            rx = inj_fe ? 0 : 1; // Send bad stop bit if injected
            #1600;
            
            rx = 1; // Idle line return
            #1600;
        end
    endtask

endmodule