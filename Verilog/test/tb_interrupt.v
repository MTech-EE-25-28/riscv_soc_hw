`timescale 1ns/1ps
// Testbench for interrupt handling in the RISC-V CPU
// load interrupt.hex in instr_mem.v
module tb_interrupt;
reg clk, reset;
reg [4:0] Interrupt;
reg Ext_MemWrite;
reg [31:0] Ext_WriteData, Ext_DataAdr;

wire [31:0] WriteData, DataAdr, ReadData;
wire MemWrite;
wire [31:0] PCW, Result, DataAdrW, WriteDataW, ReadDataW;

riscv_cpu uut (clk, reset, Interrupt, Ext_MemWrite, Ext_WriteData, Ext_DataAdr,
               MemWrite, WriteData, DataAdr, ReadData,
               PCW, Result, DataAdrW, WriteDataW, ReadDataW);

always begin clk <= 0; #8; clk <= 1; #8; end

integer handler_calls;
reg     trap_done;
initial handler_calls = 0;

initial begin
    $dumpfile("./Verilog/dumps/tb_interrupt.vcd");
    $dumpvars(0, tb_interrupt);
    reset = 0; Interrupt = 5'b0; Ext_MemWrite = 0; Ext_DataAdr = 32'b0; Ext_WriteData = 32'b0;
    #100;
    reset = 1; repeat (30) @(posedge clk);

    // trigger all 5 interrupts with some delay in between
    Interrupt = 5'b00001;
    wait(trap_done); Interrupt = 5'd0; repeat (20) @(posedge clk); // wait for handler to complete and some check if it returns to main
    Interrupt = 5'b00010;
    wait(trap_done); Interrupt = 5'd0; repeat (20) @(posedge clk);
    Interrupt = 5'b00100;
    wait(trap_done); Interrupt = 5'd0; repeat (20) @(posedge clk);
    Interrupt = 5'b01000;
    wait(trap_done); Interrupt = 5'd0; repeat (20) @(posedge clk);
    Interrupt = 5'b10000; repeat (100) @(posedge clk); // repeat trap handler trigger

    #100;
    $finish;
end

// timeout
initial begin
    #6000;
    $display("[TIMEOUT] handler_calls=%0d (expected 5)", handler_calls);
    $finish;
end

// Trap event monitor
// Fires at negedge while trap_event is high — CSR registers are updated
// on the same negedge, so mcause/mepc are already correct here.
// always @(negedge clk) begin
//     if (reset && uut.rvpl.dp.trap_event) begin
//         $display("[t=%0t] TRAP  PCW=%h  exceptionW=%6b  tretW=%b  interruptA=%5b  mie=%b  mtvec=%h  mepc=%h  mcause=%h",
//             $time, uut.rvpl.dp.PCW, uut.rvpl.dp.exceptionW, uut.rvpl.dp.tretW, uut.rvpl.dp.interruptA,
//             uut.rvpl.dp.csr_mstatus[3], uut.rvpl.dp.csr.mtvec, uut.rvpl.dp.csr.mepc, uut.rvpl.dp.csr.mcause);
//         $display("        PCF-next=%h  PCSrcTrap=%b", uut.rvpl.dp.trap_pc_next, uut.rvpl.dp.PCSrcTrap);
//     end
// end

// Handler-complete monitor
always @(negedge clk) begin
    trap_done = 0;
    if (reset && MemWrite && DataAdr == 32'h00001000 && WriteData == 32'd1) begin
        handler_calls = handler_calls + 1; trap_done = 1;
        $display("[t=%0t] Interrupt Handler #%0d done  mcause=%h", $time, handler_calls, uut.rvpl.dp.csr.mcause);
        if (handler_calls == 5) begin
            $display("Interrupt Handler called correctly, halting");
            #200; $finish;
        end
    end
end

endmodule
