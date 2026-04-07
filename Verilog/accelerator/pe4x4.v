
module pe4x4 #(parameter N = 32)(
    input clk, reset,
    input [N-1:0] A_in, B_in,
    output reg [N-1:0] A_out, B_out,
    output reg [2*N-1:0] C_out
);

reg [2*N-1:0] acc;

always @(posedge clk) begin
    if (reset) begin
        acc <= 0; A_out <= 0; B_out <= 0; C_out <= 0;
    end else begin
        acc   <= acc + (A_in * B_in);
        A_out <= A_in;
        B_out <= B_in;
        C_out <= acc + (A_in * B_in);
    end
end

endmodule