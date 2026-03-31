
// riscv_top.v - Top-level module for RISC-V SoC
module riscv_top (
    input  wire clk, e_rst, // External reset
    input  wire [4:0] irq, // External interrupts
    // debug outputs
    output  reg reset,
    output  reg [1:0] state,
    output wire [31:0] debug_reg0, debug_reg1
);

// state declaration
localparam  ST_INIT = 2'b00,
            ST_MEM = 2'b01,
            ST_RUN  = 2'b10,
            ST_DONE = 2'b11;

reg Ext_MemWrite;
reg [31:0] Ext_WriteData, Ext_DataAdr;
reg [3:0] counter;
reg [31:0] debug_regs [1:0];

wire MemWrite;
wire [31:0] WriteData, DataAdr, ReadData;
wire [31:0] PCW, Result, DataAdrW, WriteDataW, ReadDataW;

riscv_cpu rv_test (
    clk, reset, irq, Ext_MemWrite, Ext_WriteData, Ext_DataAdr,
    MemWrite, WriteData, DataAdr, ReadData, PCW, Result,
    DataAdrW, WriteDataW, ReadDataW
);

always @(posedge clk) begin
    if (!e_rst) begin
        state <= ST_INIT; reset <= 1'b0; counter <= 1'b0;
        Ext_MemWrite <= 1'b0; Ext_WriteData <= 32'b0; Ext_DataAdr <= 32'b0;
        debug_regs[0] <= 32'b0; debug_regs[1] <= 32'b0;
    end else begin
        case (state)
            ST_INIT: begin
                // Initialize memory with test program
                Ext_MemWrite <= 1'b0; Ext_WriteData <= 32'b0; Ext_DataAdr <= 32'b0;
                counter <= counter + 1'b1; reset <= 1'b0;
                // mem init wait
                if (counter == 15) state <= ST_MEM;
            end
            ST_MEM: begin
                // memory write
                counter <= counter + 1'b1; reset <= 1'b1;
                if (counter < 2) begin
                    Ext_MemWrite <= 1'b1; Ext_WriteData <= 32'h0000000A; Ext_DataAdr <= 32'h00000800;
                end else begin
                    Ext_MemWrite <= 1'b0; Ext_WriteData <= 32'b0; Ext_DataAdr <= 32'b0;
                    counter <= 1'b0; state <= ST_RUN;
                end

            end
            ST_RUN: begin
                // Wait for program to run and write result to memory
                if (MemWrite && DataAdr == 32'h00000804) begin
                    debug_regs[0] <= WriteData[31:0]; // Capture debug info
                end
                if (MemWrite && DataAdr == 32'h00000808) begin
                    debug_regs[1] <= WriteData[31:0];
                    state <= ST_DONE;
                end
            end
            ST_DONE: begin
                // Test complete, can add additional checks here if needed
                reset <= 1'b0; counter <= 1'b0;
            end
        endcase
    end
end

assign debug_reg0 = debug_regs[0];
assign debug_reg1 = debug_regs[1];

endmodule