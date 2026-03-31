
module division (
    input clk, enable,
    input [31:0] A,
    input [31:0] B,
    output reg [31:0] Quotient,
    output reg [31:0] Remainder,
    output reg valid_op
);

reg [63:0] AQ;
reg [31:0] M;
reg [31:0] Q;
reg [4:0] count = 0;

reg [63:0] tempAQ;
reg [31:0] rem;

initial valid_op = 0;

always @(posedge clk) begin
    valid_op <= 0;
    if (!enable) begin
        AQ <= 0; M  <= 0; Q <= 0; count <= 0; tempAQ <= 0; rem <= 0;
    end else begin
        // Initialization
        if(count == 0) begin
            Quotient <= 0;
            Remainder <= 0;
            AQ <= {32'b0, A};
            M <= B;
            Q <= 0;
            count <= 1;
        end
        // 16 radix-4 iterations
        else if(count <= 16) begin

            tempAQ = AQ << 2;
            rem = tempAQ[63:32];

            if(rem >= ((M<<1) + M)) begin
                rem = rem - ((M<<1) + M);
                Q = (Q << 2) | 2'b11;
            end

            else if(rem >= (M<<1)) begin
                rem = rem - (M<<1);
                Q = (Q << 2) | 2'b10;
            end

            else if(rem >= M) begin
                rem = rem - M;
                Q = (Q << 2) | 2'b01;
            end

            else begin
                Q = (Q << 2);
            end

            tempAQ[63:32] = rem;

            AQ <= tempAQ;
            count <= count + 1;

        end
        // Output stage
        else begin
            valid_op <= 1;
            Quotient <= Q;
            Remainder <= AQ[63:32];
            count <= 0;
        end
    end
end

endmodule