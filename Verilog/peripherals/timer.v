
// hardware timer peripheral for RISC-V SoC
// 2 16-bit timers with interrupt generation
// 1 32-bit timer
// timers can also generate PWM signals, one PWM per timer
// Registers:
// TCCR - Timer Control Register 0 + 1
// TCCR bit fields: [31:9] - reserved
// [8] - Interrupt1 Enable, [7] - PWM2 Enable, [6] - Timer2 Enable
// [5] - Interrupt1 Enable, [4] - PWM1 Enable, [3] - Timer1 Enable
// [2] - Interrupt0 Enable, [1] - PWM0 Enable, [0] - Timer0 Enable
// TCNT - Timer Counter Register 0 + 1
// TCNT bit fields: [31:16] TCNT1, [15:0] TCNT0 => (0-65535)
// TCNTF - Timer Counter Register 2, 32-bit counter
// OCMR - Output Compare Register 0 + 1 (for PWM generation)
// OCMR bit fields: [31:16] OCMR1, [15:0] OCMR0 => (0-65535) compare value for PWM duty cycle
// OCMRF - Output Compare Register 2, 32-bit compare value
// feel free to add more registers for auto-reload, prescaler, etc. if needed (i am lazy)
// TIRQ - Timer Interrupt Register (read-only)
// TIRQ bit fields: [31:3] - reserved, [2] - Compare match,
// Timer 2 => [1] - Overflow, [0] - Compare match
// Timer 1 => [1] - Overflow, [0] - Compare match
// Timer 0 => [1] - Overflow, [0] - Compare match
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
    output reg         irq,
    output reg         pwm_out0,
    output reg         pwm_out1,
    output reg         pwm_out2

);


localparam TCCR_ADDR  = BASE_ADDR;           // BASE + 0x00
localparam TCNT_ADDR  = BASE_ADDR + 32'h04;  // BASE + 0x04
localparam TCNTF_ADDR = BASE_ADDR + 32'h08;  // BASE + 0x08
localparam OCMR_ADDR  = BASE_ADDR + 32'h0C;  // BASE + 0x0C
localparam OCMRF_ADDR = BASE_ADDR + 32'h10;  // BASE + 0x10
localparam TIRQ_ADDR  = BASE_ADDR + 32'h14;  // BASE + 0x14

reg [31:0] TCCR;  // Timer Control Register
reg [31:0] TCNT;  // Timer Counter Register 0+1 (read-only)
reg [31:0] TCNTF; // Timer Counter Register 2 (read-only)
reg [31:0] OCMR;  // Output Compare Register 0+1
reg [31:0] OCMRF; // Output Compare Register 2
reg [5:0]  TIRQ;  // Timer Interrupt Register (read-to-clear)
reg [5:0]  TIRQ_prev; // Previous TIRQ state for edge detection
reg [15:0] counter0, counter1; // internal counters for timer 0 and 1
reg [31:0] counter2;           // internal counter for timer 2

// Intermediate signals for interrupt flag setting
wire timer0_cmp_match = (counter0 >= OCMR[15:0]) && TCCR[0];
wire timer0_overflow = (counter0 == 16'hFFFF) && TCCR[0];
wire timer1_cmp_match = (counter1 >= OCMR[31:16]) && TCCR[3];
wire timer1_overflow = (counter1 == 16'hFFFF) && TCCR[3];
wire timer2_cmp_match = (counter2 >= OCMRF) && TCCR[6];
wire timer2_overflow = (counter2 == 32'hFFFFFFFF) && TCCR[6];

always @(posedge clk) begin // apb write transaction
    if (!resetn) begin
        TCCR <= 32'b0;
        OCMR <= 32'b0;
        OCMRF <= 32'b0;
        pslverr <= 1'b0;
    end else if (psel && penable && pwrite) begin
        case (paddr)
            TCCR_ADDR:  TCCR <= pwdata;
            OCMR_ADDR:  OCMR <= pwdata;
            OCMRF_ADDR: OCMRF <= pwdata;
            default:    pslverr <= 1'b1;
        endcase
    end
end

always @(*) begin // apb read transaction
    if (psel && penable && !pwrite) begin
        case (paddr) // read
            TCCR_ADDR:  prdata = TCCR;
            TCNT_ADDR:  prdata = TCNT;
            TCNTF_ADDR: prdata = TCNTF;
            OCMR_ADDR:  prdata = OCMR;
            OCMRF_ADDR: prdata = OCMRF;
            TIRQ_ADDR:  prdata = {26'b0, TIRQ}; // Read returns current flags
            default:    prdata = 32'b0;
        endcase
    end else begin
        prdata = 32'b0;
    end
end

// TIRQ management (single driver for TIRQ register)
always @(posedge clk) begin
    if (!resetn) begin
        TIRQ <= 6'b0;
        TIRQ_prev <= 6'b0;
    end else begin
        TIRQ_prev <= TIRQ; // Store previous state for edge detection

        // Clear TIRQ when read
        if (psel && penable && !pwrite && paddr == TIRQ_ADDR) begin
            TIRQ <= 6'b0;
        end else begin
            // Set interrupt flags based on timer events
            if (timer0_cmp_match) TIRQ[0] <= 1'b1;
            if (timer0_overflow)  TIRQ[1] <= 1'b1;
            if (timer1_cmp_match) TIRQ[2] <= 1'b1;
            if (timer1_overflow)  TIRQ[3] <= 1'b1;
            if (timer2_cmp_match) TIRQ[4] <= 1'b1;
            if (timer2_overflow)  TIRQ[5] <= 1'b1;
        end
    end
end

assign pready = (psel && penable) ? 1'b1 : 1'b0; // assert only in APB access phase

// timer 0 counting logic
always @(posedge clk) begin
    if (!resetn) begin
        counter0 <= 16'b0;
        pwm_out0 <= 1'b0;
    end else if (TCCR[0]) begin // timer 0 enabled
        counter0 <= counter0 + 1;

        // Check for compare match
        if (counter0 >= OCMR[15:0]) begin
            counter0 <= 16'b0;

            if (TCCR[1]) begin // PWM enabled
                pwm_out0 <= ~pwm_out0; // toggle PWM output on compare match
            end
        end
    end else begin
        counter0 <= 16'b0;
        pwm_out0 <= 1'b0;
    end
end

// timer 1 counting logic
always @(posedge clk) begin
    if (!resetn) begin
        counter1 <= 16'b0;
        pwm_out1 <= 1'b0;
    end else if (TCCR[3]) begin // timer 1 enabled
        counter1 <= counter1 + 1;

        // Check for compare match
        if (counter1 >= OCMR[31:16]) begin
            counter1 <= 16'b0;

            if (TCCR[4]) begin // PWM enabled
                pwm_out1 <= ~pwm_out1; // toggle PWM output on compare match
            end
        end
    end else begin
        counter1 <= 16'b0;
        pwm_out1 <= 1'b0;
    end
end

// timer 2 counting logic (32-bit timer)
always @(posedge clk) begin
    if (!resetn) begin
        counter2 <= 32'b0;
        pwm_out2 <= 1'b0;
    end else if (TCCR[6]) begin // timer 2 enabled
        counter2 <= counter2 + 1;

        // Check for compare match
        if (counter2 >= OCMRF) begin
            counter2 <= 32'b0;

            if (TCCR[7]) begin // PWM enabled
                pwm_out2 <= ~pwm_out2; // toggle PWM output on compare match
            end
        end
    end else begin
        counter2 <= 32'b0;
        pwm_out2 <= 1'b0;
    end
end

// Update read-only counter registers
always @(*) begin
    TCNT = {counter1, counter0};
    TCNTF = counter2;
end

// Generate single-cycle interrupt pulse (edge detection on TIRQ flags)
always @(posedge clk) begin
    if (!resetn) begin
        irq <= 1'b0;
    end else begin
        irq <= (TCCR[2] && (TIRQ[0] && !TIRQ_prev[0])) ||  // Timer 0 compare match (rising edge)
               (TCCR[2] && (TIRQ[1] && !TIRQ_prev[1])) ||  // Timer 0 overflow (rising edge)
               (TCCR[5] && (TIRQ[2] && !TIRQ_prev[2])) ||  // Timer 1 compare match (rising edge)
               (TCCR[5] && (TIRQ[3] && !TIRQ_prev[3])) ||  // Timer 1 overflow (rising edge)
               (TCCR[8] && (TIRQ[4] && !TIRQ_prev[4])) ||  // Timer 2 compare match (rising edge)
               (TCCR[8] && (TIRQ[5] && !TIRQ_prev[5]));    // Timer 2 overflow (rising edge)
    end
end

endmodule