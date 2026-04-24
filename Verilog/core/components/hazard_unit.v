
// hazard_unit.v - Hazard Detection and Forwarding Unit for RISC-V Pipeline CPU
module hazard_unit (
    input clk, reset,
    input [4:0] Rs1D, Rs2D, Rs1E, Rs2E,
    input [4:0] RdE, RdM, RdW,
    input RsE0, RegWriteM, RegWriteW, PCSrcE,
    // peripheral stall: address + APB-done release
    input [31:0] ResultM,  // M-stage address — detect peripheral range here
    input        apb_done, // pulsed high by axi_interface when APB transaction completes
    input        is_mem_accessM, // MemWriteM || ResultSrcM[0]: gate ph_stall on real mem ops only
    input        validM,   // M-stage valid: only stall on real instructions, not bubbles
    input        wfiD,     // WFI instruction in Decode stage
    input        interrupt_pending, // Any interrupt pending (release WFI stall)
    output reg   StallF, StallD,
    output reg   FlushD, FlushE,
    output reg [1:0] ForwardAE, ForwardBE,
    output wire  mem_stall  // driven combinationally: (ResultM in periph range) && !apb_done
);

// Combinational peripheral stall: freeze the whole pipeline as soon as the
// M-stage address falls in the peripheral range, release when APB signals done.
// Only stall for actual load/store instructions whose address is in peripheral range.
wire ph_stall = (ResultM >= 32'h0000_2000 && ResultM < 32'h0000_2400) && is_mem_accessM && validM;
assign mem_stall = ph_stall && !apb_done;

// WFI stall: stall Fetch when WFI is in Decode stage and no interrupt is pending
// This keeps PC on the WFI instruction until an interrupt arrives
wire wfi_stall = wfiD && !interrupt_pending;

reg lwStall = 0;

always @(*) begin
    if (!reset) begin
        StallF = 0; StallD = 0; ForwardAE = 0;
        FlushD = 1; FlushE = 1; ForwardBE = 0;  // Flush pipeline during reset
    end else begin
        if (((Rs1E == RdM) & RegWriteM) && (Rs1E != 0)) ForwardAE = 2'b10;
        else if (((Rs1E == RdW) & RegWriteW) && (Rs1E != 0)) ForwardAE = 2'b01;
        else ForwardAE = 2'b00;

        if (((Rs2E == RdM) & RegWriteM) && (Rs2E != 0)) ForwardBE = 2'b10;
        else if (((Rs2E == RdW) & RegWriteW) && (Rs2E != 0)) ForwardBE = 2'b01;
        else ForwardBE = 2'b00;

        lwStall = RsE0 & ((Rs1D == RdE) | (Rs2D == RdE));
// WFI stall: only stall Fetch (keep PC on WFI), don't stall Decode
        // This allows WFI to drain through pipeline while PC stays put
        StallF = lwStall || mem_stall || wfi_stall;
        StallD = lwStall || mem_stall;
        StallD = lwStall || mem_stall || wfi_stall;

        FlushD = PCSrcE;
        FlushE = (lwStall && !mem_stall) | PCSrcE;
    end
end


endmodule