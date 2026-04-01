
module division_top (
    input clk,
    input enable,
    input [31:0] rs1, rs2,
    input [2:0] funct3,
    output reg [31:0] rd,
    output reg valid_op_d
);

reg signA;
reg signB;
reg select_remainder;

wire signA_neg;
wire signB_neg;

// Internal enable gating to prevent restart when valid goes high
reg enable_hold;
wire internal_enable = enable && !enable_hold;

// Input latching to preserve operands during multi-cycle operation
reg latched;
reg [31:0] lat_rs1, lat_rs2;
reg [2:0] lat_funct3;

initial enable_hold = 1'b0;
initial latched = 1'b0;

always @(posedge clk) begin
    if (valid_op_d)
        enable_hold <= 1'b1;
    else
        enable_hold <= 1'b0;
end

always @(posedge clk) begin
    if (!enable) begin
        latched <= 1'b0;
    end else if (!latched && !valid_op_d) begin
        lat_rs1 <= rs1;
        lat_rs2 <= rs2;
        lat_funct3 <= funct3;
        latched <= 1'b1;
    end else if (valid_op_d) begin
        latched <= 1'b0;
    end
end

wire [31:0] rs1_in = latched ? lat_rs1 : rs1;
wire [31:0] rs2_in = latched ? lat_rs2 : rs2;
wire [2:0] funct3_in = latched ? lat_funct3 : funct3;

wire valid_op;

wire [31:0] opA_mag;
wire [31:0] opB_mag;

wire [31:0] quotient_mag;
wire [31:0] remainder_mag;

wire result_neg;

wire [31:0] quotient_signed;
wire [31:0] remainder_signed;


// Instruction Decode
always @(*) begin
    signA = 1'b0; signB = 1'b0; select_remainder = 1'b0;
    if (internal_enable) begin
        case (funct3_in)
            3'b100: begin // DIV
                signA = 1'b1;
                signB = 1'b1;
                select_remainder = 1'b0;
            end

            3'b101: begin // DIVU
                signA = 1'b0;
                signB = 1'b0;
                select_remainder = 1'b0;
            end

            3'b110: begin // REM
                signA = 1'b1;
                signB = 1'b1;
                select_remainder = 1'b1;
            end

            3'b111: begin // REMU
                signA = 1'b0;
                signB = 1'b0;
                select_remainder = 1'b1;
            end
        endcase
    end
end

// Sign Handling
assign signA_neg = signA & rs1_in[31];
assign signB_neg = signB & rs2_in[31];

assign opA_mag = signA_neg ? (~rs1_in + 1'b1) : rs1_in;
assign opB_mag = signB_neg ? (~rs2_in + 1'b1) : rs2_in;

assign result_neg = signA_neg ^ signB_neg;

// Division Block Instantiation
division u_divider (
    .clk(clk), .enable(internal_enable),
    .A(opA_mag),
    .B(opB_mag),
    .Quotient(quotient_mag),
    .Remainder(remainder_mag),
    .valid_op(valid_op)
);

// Sign Correction
assign quotient_signed  = result_neg ? (~quotient_mag + 1'b1) : quotient_mag;
assign remainder_signed = signA_neg ? (~remainder_mag + 1'b1) : remainder_mag;

// Output Selection
always @(posedge clk) begin
    valid_op_d <= 0;
    if (internal_enable && valid_op) begin
        if (select_remainder) begin
            valid_op_d <= 1'b1;
            if (signA || signB)
                rd <= remainder_signed;
            else
                rd <= remainder_mag;
        end else begin
            valid_op_d <= 1'b1;
            if (signA || signB)
                rd <= quotient_signed;
            else
                rd <= quotient_mag;
        end
    end
end

endmodule