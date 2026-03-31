
module dadda_multiplier (
    input clk, enable,      // clock, enable
    input [31:0] rs1, rs2,  // input registers
    input [2:0] funct3,     // identify mul type
    output reg [31:0] rd,   // result
    output reg valid_op     // valid
);

// Sign Registers and High Indication bit
reg signA, signB, select_high;

// used to detect if number is negative
wire signA_neg, signB_neg, result_neg;

// inputs to dadda block
wire [31:0] opA_mag, opB_mag;

// magnitude and signed version of product
wire [63:0] product_mag, product_signed;

// partial product array
wire [63:0] PP [0:31];

// dadda inputs and outputs, valid_output
wire [31:0] A, B;
reg [63:0] P;
reg reg_valid_op;

// stage signals
wire [63:0] s1 [0:15];
wire [63:0] s2 [0:7];
wire [63:0] s3 [0:3];
wire [63:0] s4 [0:1];

// pipeline registers
reg [63:0] s1_reg [0:15];
reg [63:0] s2_reg [0:7];
reg [63:0] s3_reg [0:3];
reg [63:0] s4_reg [0:1];

// Sign and Select high signals used for propogating
reg select_high1, select_high2, select_high3, select_high4, select_high5;
reg result_neg1, result_neg2, result_neg3, result_neg4, result_neg5;
reg signA1, signA2, signA3, signA4, signA5;
reg signB1, signB2, signB3, signB4, signB5;
reg [2:0] stage=0;

// zero bypass
wire zero_case;

// Internal enable gating to prevent restart when valid goes high
reg enable_hold;
wire internal_enable = enable && !enable_hold;

// Input latching to preserve operands during multi-cycle operation
reg latched;
reg [31:0] lat_rs1, lat_rs2;
reg [2:0] lat_funct3;

initial valid_op = 1'b0;
initial enable_hold = 1'b0;
initial latched = 1'b0;

always @(posedge clk) begin
    if (valid_op)
        enable_hold <= 1'b1;
    else
        enable_hold <= 1'b0;
end

always @(posedge clk) begin
    if (!enable) begin
        latched <= 1'b0;
    end else if (!latched && !valid_op) begin
        lat_rs1 <= rs1;
        lat_rs2 <= rs2;
        lat_funct3 <= funct3;
        latched <= 1'b1;
    end else if (valid_op) begin
        latched <= 1'b0;
    end
end

wire [31:0] rs1_in = latched ? lat_rs1 : rs1;
wire [31:0] rs2_in = latched ? lat_rs2 : rs2;
wire [2:0] funct3_in = latched ? lat_funct3 : funct3;

// Detection of Zero case only on internal_enable
assign zero_case = internal_enable ? (~|rs1_in || ~|rs2_in) : 1'b0;

// ---------------- Decode ----------------
always @(*) begin
    signA <= 0; signB <= 0; select_high <= 0;
    if(internal_enable) begin
        case(funct3_in)

        3'b000: begin // MUL
            signA <= 1;
            signB <= 1;
        end

        3'b001: begin // MULH
            signA <= 1;
            signB <= 1;
            select_high <= 1;
        end

        3'b010: begin // MULHSU
            signA <= 1;
            select_high <= 1;
        end

        3'b011: begin // MULHU
            select_high <= 1;
        end
        endcase
    end
end

// ---------------- Sign Handling ----------------
assign signA_neg = signA & rs1_in[31];
assign signB_neg = signB & rs2_in[31];

assign A = signA_neg ? (~rs1_in + 1'b1) : rs1_in;
assign B = signB_neg ? (~rs2_in + 1'b1) : rs2_in;

assign result_neg = signA_neg ^ signB_neg;

//--------------------------------------------------
// ---------------- Multiplier Core ----------------
//--------------------------------------------------

// ---------------- Partial Product ----------------
genvar i;
generate for(i=0;i<32;i=i+1) begin : PP_GEN
    assign PP[i] = B[i] ? ({32'b0,A} << i) : 64'b0;
end
endgenerate

// ---------------- Stage1 (32 ? 16) ----------------
genvar j;
generate for(j=0;j<16;j=j+1) begin : Stage_1
    assign s1[j] = PP[2*j] + PP[2*j+1];
end
endgenerate

integer k;
always @(posedge clk) begin
    select_high1 <= select_high;
    result_neg1 <= result_neg;
    signA1 <= signA;
    signB1 <= signB;
    for(k=0;k<16;k=k+1) begin
        s1_reg[k] <= s1[k];
    end
end

// ---------------- Stage2 (16 ? 8) ----------------
generate for(j=0;j<8;j=j+1) begin
    assign s2[j] = s1_reg[2*j] + s1_reg[2*j+1];
end
endgenerate

always @(posedge clk) begin : Stage_2
    select_high2 <= select_high1;
    result_neg2 <= result_neg1;
    signA2 <= signA1;
    signB2 <= signB1;
    for(k=0;k<8;k=k+1)
        s2_reg[k] <= s2[k];
end

// ---------------- Stage3 (8 ? 4) ----------------
generate for(j=0;j<4;j=j+1) begin : Stage_3
    assign s3[j] = s2_reg[2*j] + s2_reg[2*j+1];
end
endgenerate

always @(posedge clk) begin
    select_high3 <= select_high2;
    result_neg3 <= result_neg2;
    signA3 <= signA2;
    signB3 <= signB2;
    for(k=0;k<4;k=k+1)
        s3_reg[k] <= s3[k];
end


// ---------------- Stage4 (4 ? 2) ----------------
generate for(j=0;j<2;j=j+1) begin : Stage_4
    assign s4[j] = s3_reg[2*j] + s3_reg[2*j+1];
end
endgenerate

always @(posedge clk) begin
    select_high4 <= select_high3;
    result_neg4 <= result_neg3;
    signA4 <= signA3;
    signB4 <= signB3;
    for(k=0;k<2;k=k+1)
        s4_reg[k] <= s4[k];
end

// ---------------- Final Stage ----------------
always @(posedge clk) begin
    select_high5 <= select_high4;
    result_neg5 <= result_neg4;
    signA5 <= signA4;
    signB5 <= signB4;
    P <= s4_reg[0] + s4_reg[1];
    if (valid_op || zero_case || !internal_enable) begin
        reg_valid_op <= 1'b0; stage <= 1'b0;
    end else if (stage < 5) stage <= stage + 1'b1;
    else reg_valid_op <= 1'b1;
end

assign product_mag = P;

//--------------------------------------------------------------------

// Signed Product Calculation
assign product_signed = result_neg5 ? (~product_mag + 1'b1) : product_mag;

// ---------------- Output Logic ----------------
always @(posedge clk) begin
    valid_op <= 0;
    if(internal_enable) begin
        if(zero_case) begin
            rd <= 32'h0;
            valid_op <= 1;
        end else begin
            if (reg_valid_op && !valid_op) begin // valid for one cycle
                if(select_high5) begin
                    if(signA5 || signB5)
                        rd <= product_signed[63:32];
                    else
                        rd <= product_mag[63:32];
                end else begin
                    rd <= product_signed[31:0];
                end
                valid_op <= 1;
            end
        end
    end
end
endmodule