
// hazard_unit.v - Hazard Detection and Forwarding Unit for RISC-V Pipeline CPU
module hazard_unit (
    input clk, reset,
    input [4:0] Rs1D, Rs2D, Rs1E, Rs2E,
    input [4:0] RdE, RdM, RdW,
    input RsE0, RegWriteM, RegWriteW, PCSrcE,
    output reg StallF, StallD,
    output reg FlushD, FlushE,
    output reg [1:0] ForwardAE, ForwardBE
);

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

        StallF = lwStall; StallD = lwStall;

        FlushD = PCSrcE;
        FlushE = lwStall | PCSrcE;
    end
end


endmodule