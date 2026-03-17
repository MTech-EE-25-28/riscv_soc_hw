
// alu.v - ALU module
module alu #(parameter WIDTH = 32) (
    input       clk,                    // clock
    input       [WIDTH-1:0] a, b,       // operands
    input       [4:0] alu_ctrl,         // ALU control
    output reg  [WIDTH-1:0] alu_out,    // ALU output
    output      zero,                   // zero flag
    output      stall
);

reg [31:0] mask = 0;

wire [31:0] r_adder, r_diff;
wire carry_a, carry_s;

bk_adder #(32) adder (a, b, 1'b0, r_adder, carry_a);
bk_adder #(32) diff  (a, b, 1'b1,  r_diff, carry_s); // if cin = 1 means sub

wire mul_valid;
wire [31:0] r_mult;

// Latch multiply inputs on the first execute cycle so they stay stable
// during stall (forwarding muxes change as M/WB stages advance freely).
wire        enable = alu_ctrl[4];
reg         mul_latched;
reg [31:0]  a_mul, b_mul;
reg [2:0]   f_mul;

always @(posedge clk) begin
    if (!enable) begin
        mul_latched <= 0;
    end else if (!mul_latched) begin
        a_mul       <= a;
        b_mul       <= b;
        f_mul       <= alu_ctrl[2:0];
        mul_latched <= 1;
    end else if (mul_valid) begin
        mul_latched <= 0;  // reset when result is consumed
    end
end

wire [31:0] mul_a = mul_latched ? a_mul : a;
wire [31:0] mul_b = mul_latched ? b_mul : b;
wire [2:0]  mul_f = mul_latched ? f_mul : alu_ctrl[2:0];

dadda_multiplier mult (clk, enable, mul_a, mul_b, mul_f, r_mult, mul_valid);

always @(*) begin
    mask = 0;
    casez (alu_ctrl)
        5'b00000:  alu_out = r_adder;               // ADD
        5'b00001:  alu_out = r_diff;                // SUB
        5'b00010:  alu_out = a << {27'b0,b[4:0]};   // SLL
        5'b00011:  begin                            // SLT
            if (a[31] != b[31]) alu_out = a[31] ? 1 : 0;
            else alu_out = a < b ? 1 : 0;
        end
        5'b00100:  alu_out = a < b ? 1 : 0;         // SLTU
        5'b00101:  alu_out = a ^ b;                 // XOR
        5'b00110:  alu_out = a >> {27'b0,b[4:0]};   // SRL
        5'b00111:  begin //SRA
            if (a[31]) mask = ~(32'hFFFF_FFFF >> {27'b0,b[4:0]});
            else begin
                mask = 32'h0000_0000;
            end
            alu_out = (a >> {27'b0,b[4:0]}) | mask;
        end
        5'b01000:  alu_out = a | b;                 // OR
        5'b01001:  alu_out = a & b;                 // AND
        5'b100??:  alu_out = r_mult;                // MULxx
        // 5'b111??:  alu_out = r_div;                 // DIV/REMxx
        default: alu_out = 0;
    endcase
end

assign  zero = (alu_out == 0) ? 1'b1 : 1'b0;
assign stall = (alu_ctrl[4] && !mul_valid) ? 1'b1 : 1'b0;
// assign stall = 1'b0;

endmodule