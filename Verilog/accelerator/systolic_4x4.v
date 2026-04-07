
module systolic_4x4 #(parameter N = 32)(
    input clk,
    input reset,

    // Streamed inputs
    input [N-1:0] A1, A2, A3, A4,
    input [N-1:0] B1, B2, B3, B4,

    // Outputs
    output [2*N-1:0] C11, C12, C13, C14,
    output [2*N-1:0] C21, C22, C23, C24,
    output [2*N-1:0] C31, C32, C33, C34,
    output [2*N-1:0] C41, C42, C43, C44
);

// Internal wires
wire [N-1:0] a12,a13,a14;
wire [N-1:0] a22,a23,a24;
wire [N-1:0] a32,a33,a34;
wire [N-1:0] a42,a43,a44;

wire [N-1:0] b21,b22,b23,b24;
wire [N-1:0] b31,b32,b33,b34;
wire [N-1:0] b41,b42,b43,b44;

// Dummy wires for unused outputs
wire [N-1:0] dummy_a14, dummy_a24, dummy_a34, dummy_a44;
wire [N-1:0] dummy_b41, dummy_b42, dummy_b43, dummy_b44;

// Row 1
pe4x4 PE11(clk,reset,A1,B1,a12,b21,C11);
pe4x4 PE12(clk,reset,a12,B2,a13,b22,C12);
pe4x4 PE13(clk,reset,a13,B3,a14,b23,C13);
pe4x4 PE14(clk, reset, a14, B4, dummy_a14, b24, C14);

// Row 2
pe4x4 PE21(clk,reset,A2,b21,a22,b31,C21);
pe4x4 PE22(clk,reset,a22,b22,a23,b32,C22);
pe4x4 PE23(clk,reset,a23,b23,a24,b33,C23);
pe4x4 PE24(clk, reset, a24, b24, dummy_a24, b34, C24);

// Row 3
pe4x4 PE31(clk,reset,A3,b31,a32,b41,C31);
pe4x4 PE32(clk,reset,a32,b32,a33,b42,C32);
pe4x4 PE33(clk,reset,a33,b33,a34,b43,C33);
pe4x4 PE34(clk, reset, a34, b34, dummy_a34, b44, C34);

// Row 4
pe4x4 PE41(clk, reset, A4, b41, a42, dummy_b41, C41);
pe4x4 PE42(clk, reset, a42, b42, a43, dummy_b42, C42);
pe4x4 PE43(clk, reset, a43, b43, a44, dummy_b43, C43);
pe4x4 PE44(clk, reset, a44, b44, dummy_a44, dummy_b44, C44);

endmodule