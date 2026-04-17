
module division (
    input             clk,
    input             enable,
    input      [31:0] A,
    input      [31:0] B,
    output reg [31:0] Quotient,
    output reg [31:0] Remainder,
    output reg        valid_op
);

reg [63:0] AQ;
reg [31:0] M;
reg [31:0] Q;
reg  [4:0] count;

// Combinational radix-4 iteration logic (operates on current AQ, M, Q)
wire [63:0] shifted = AQ << 2;
wire [31:0] rem_top = shifted[63:32];

// Use 33-bit arithmetic to avoid overflow when computing 2*M and 3*M
wire [32:0] rem33 = {1'b0, rem_top};
wire [32:0] M33   = {1'b0, M};
wire [32:0] M2    = M33 << 1;
wire [32:0] M3    = M2 + M33;

wire sel3 = (rem33 >= M3);
wire sel2 = ~sel3 & (rem33 >= M2);
wire sel1 = ~sel3 & ~sel2 & (rem33 >= M33);

wire [32:0] rem_next =  sel3 ? (rem33 - M3)  :
                        sel2 ? (rem33 - M2)  :
                        sel1 ? (rem33 - M33) :
                                rem33;

wire [1:0] q_bits = sel3 ? 2'b11 :
                    sel2 ? 2'b10 :
                    sel1 ? 2'b01 :
                            2'b00;

wire [63:0] AQ_next = {rem_next[31:0], shifted[31:0]};
wire [31:0]  Q_next = (Q << 2) | {30'd0, q_bits};

// Sequential logic
always @(posedge clk) begin
    valid_op <= 1'b0;

    if (!enable) begin
        AQ    <= 64'd0;
        M     <= 32'd0;
        Q     <= 32'd0;
        count <= 5'd0;
    end else begin
        // Initialization
        if (count == 5'd0) begin
            Quotient  <= 32'd0;
            Remainder <= 32'd0;
            AQ        <= {32'd0, A};
            M         <= B;
            Q         <= 32'd0;
            count     <= 5'd1;
        end
        // 16 radix-4 iterations
        else if (count <= 5'd16) begin
            AQ    <= AQ_next;
            Q     <= Q_next;
            count <= count + 5'd1;
        end
        // Output stage
        else begin
            valid_op  <= 1'b1;
            Quotient  <= Q;
            Remainder <= AQ[63:32];
            count     <= 5'd0;
        end
    end
end

endmodule