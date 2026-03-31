
// Testbench for exception handling in the RISC-V CPU
// load exception.hex in instr_mem.v
module tb_exception;
reg clk, reset;
reg Ext_MemWrite;
reg [31:0] Ext_WriteData, Ext_DataAdr;

wire [31:0] WriteData, DataAdr, ReadData;
wire MemWrite;
wire [31:0] PCW, Result, DataAdrW, WriteDataW, ReadDataW;

riscv_cpu uut (clk, reset, 5'b0, Ext_MemWrite, Ext_WriteData, Ext_DataAdr,
               MemWrite, WriteData, DataAdr, ReadData,
               PCW, Result, DataAdrW, WriteDataW, ReadDataW);

always begin clk <= 0; #8; clk <= 1; #8; end

integer handler_calls;
initial handler_calls = 0;

initial begin
    $dumpfile("./Verilog/dumps/tb_exception.vcd");
    $dumpvars(0, tb_exception);
    reset = 0;
    Ext_MemWrite = 0; Ext_DataAdr = 32'b0; Ext_WriteData = 32'b0;
    #100;
    reset = 1; @(posedge clk);

    #30000;
    $display("[TIMEOUT] handler_calls=%0d (expected 3)", handler_calls);
    $finish;
end

// Trap event monitor
// Fires at negedge while trap_event is high — CSR registers are updated
// on the same negedge, so mcause/mepc are already correct here.
// always @(negedge clk) begin
//     if (reset && uut.rvpl.dp.trap_event) begin
//         $display("[t=%0t] TRAP  PCW=%h  exceptionW=%6b  mtvec=%h  mepc=%h  mcause=%0d",
//             $time,
//             uut.rvpl.dp.PCW,
//             uut.rvpl.dp.exceptionW,
//             uut.rvpl.dp.csr.mtvec,
//             uut.rvpl.dp.csr.mepc,
//             uut.rvpl.dp.csr.mcause);
//         $display("             PCF-next=%h  PCSrcTrap=%b",
//             uut.rvpl.dp.trap_pc_next,
//             uut.rvpl.dp.PCSrcTrap);
//     end
// end

// Handler-complete monitor
always @(negedge clk) begin
    if (reset && MemWrite && DataAdr == 32'h00002000 && WriteData == 32'd1) begin
        handler_calls = handler_calls + 1;
        // $display("[t=%0t] Handler #%0d done  mcause=%0d  mepc=%h", $time, handler_calls, uut.rvpl.dp.csr.mcause, uut.rvpl.dp.csr.mepc);
        $display("[t=%0t] Handler #%0d done  mcause=%0d", $time, handler_calls, uut.rvpl.dp.csr.mcause);
        if (handler_calls == 3) begin
            $display("Handler called correctly, halting");
            #200; $finish;
        end
    end
end

endmodule
