// IOBUF.v - Behavioral simulation model for Xilinx IOBUF primitive
// Matches Vivado IOBUF port contract:
//   I  - data to drive onto IO when T=0
//   O  - data sampled from IO (always reads the pin regardless of direction)
//   IO - bidirectional pad
//   T  - tristate enable: 0=drive, 1=high-Z (input)
module IOBUF (
    input  wire I,
    output wire O,
    inout  wire IO,
    input  wire T
);
    assign IO = T ? 1'bz : I;
    assign O  = IO;
endmodule
