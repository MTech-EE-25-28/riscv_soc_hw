
// hardware timer peripheral for RISC-V SoC
// 2 16-bit timers with interrupt generation
// timers can also generate PWM signals, one PWM per timer
// Registers:
// TCCR - Timer Control Register 0 + 1
// TCCR bit fields: [31:16] TCCR1, [15:0] TCCR0
// TCCR0 -> [15:3] - reserved, [2] - Interrupt Enable, [1] - PWM Enable, [0] - Timer Enable
// TCNT - Timer Counter Register 0 + 1
// TCNT bit fields: [31:16] TCNT1, [15:0] TCNT0 => (0-65535)
// OCMR - Output Compare Register 0 + 1 (for PWM generation)
// OCMR bit fields: [31:16] OCMR1, [15:0] OCMR0 => (0-65535) compare value for PWM duty cycle
// feel free to add more registers for auto-reload, prescaler, etc. if needed (i am lazy)

module timer #(
    parameter BASE_ADDR = 32'h0000_2080,
    parameter BASE_FREQ = 32'h12C00000 // 3250000000 // 50 MHz
) (
    input  wire        clk,
    input  wire        resetn,

    // APB Interface
    input  wire        pclk,
    input  wire        presetn,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output reg         pslverr,

    // Interrupt
    output reg         irq, // (only for timer 0)
    output reg         pwm_out0,
    output reg         pwm_out1

);


localparam TCCR_ADDR = BASE_ADDR;           // BASE + 0x00
localparam TCNT_ADDR = BASE_ADDR + 32'h4;   // BASE + 0x04
localparam OCMR_ADDR = BASE_ADDR + 32'h8;   // BASE + 0x08

reg [31:0] TCCR; // Timer Control Register
reg [31:0] TCNT; // Timer Counter Register (read-only)
reg [31:0] OCMR; // Output Compare Register
reg [15:0] counter0, counter1; // internal counters

always @(posedge clk) begin // apb write transaction
    if (!resetn) begin
        TCCR <= 32'b0; OCMR <= 32'b0; pslverr <= 1'b0;
    end else if (psel && penable && pwrite) begin
        case (paddr)
            TCCR_ADDR: TCCR <= pwdata;
            OCMR_ADDR: OCMR <= pwdata;
            default:   pslverr <= 1'b1;
        endcase
    end
end

always @(*) begin // apb read transaction
    if (psel && penable && !pwrite) begin
        case (paddr) // read
            TCCR_ADDR: prdata = TCCR;
            TCNT_ADDR: prdata = TCNT;
            OCMR_ADDR: prdata = OCMR;
            default:   prdata = 32'b0;
        endcase
    end else begin
        prdata = 32'b0;
    end
end

assign pready = (psel && penable) ? 1'b1 : 1'b0; // assert only in APB access phase

// timer counting logic
always @(posedge clk) begin
    if (!resetn) begin
        counter0 <= 16'b0; irq <= 1'b0; pwm_out0 <= 1'b0;
    end else if (TCCR[0]) begin // timer enabled
        counter0 <= counter0 + 1; irq <= 1'b0;
        if (counter0 >= OCMR[15:0]) begin
            counter0 <= 16'b0;
            if (TCCR[1]) begin // PWM enabled
                pwm_out0 <= ~pwm_out0; // toggle PWM output on compare match
            end
            if (TCCR[2]) begin // interrupt enabled and compare match
                irq <= 1'b1; // raise interrupt, no interrupt on overflow
            end
        end
    end else begin
        counter0 <= 16'b0; irq <= 1'b0; pwm_out0 <= 1'b0; // reset counter and clear interrupt when timer disabled
    end
end

// timer 1 counting logic (same as timer 0 but no interrupt)
always @(posedge clk) begin
    if (!resetn) begin
        counter1 <= 16'b0; pwm_out1 <= 1'b0;
    end else if (TCCR[16]) begin // timer 1 enabled
        counter1 <= counter1 + 1;
        if (counter1 >= OCMR[31:16]) begin
            counter1 <= 16'b0; // reset counter on compare match, no interrupt
            if (TCCR[17]) begin // PWM enabled
                pwm_out1 <= ~pwm_out1; // toggle PWM output on compare match
            end
        end
    end else begin
        counter1 <= 16'b0; pwm_out1 <= 1'b0; // reset counter and PWM output when timer disabled
    end
end

always @(*) begin
    if (!resetn) begin
        TCNT <= 32'b0;
    end else begin
        TCNT <= {counter1, counter0};
    end
end

endmodule