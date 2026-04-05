
// AXI APB Interface for CPU-Peripheral Communication
// master
module axi_interface (
    input  wire        clk, resetn,

    // APB Interface
    input  wire        pclk,
    input  wire        presetn,
    input  wire        pready,
    input  wire [31:0] prdata,
    input  wire        pslverr,
    output  reg [31:0] paddr,
    output  reg [4:0]  psel,
    output  reg        penable,
    output  reg        pwrite,
    output  reg [31:0] pwdata,

    // CPU Interface
    input  wire [31:0] cpu_paddr,
    input  wire [31:0] cpu_wdata,
    input  wire        write, // 0 - read
    output reg         stall,    // stall CPU during APB transaction
    output reg  [31:0] cpu_rdata, // captured peripheral read data

    // Peripheral interface
    output wire  [4:0] irq,
    // Pads
    output wire        pwm_out0, pwm_out1,
    inout  wire [31:0] gpio_pad
);

localparam  IDLE  = 2'b00,
            WRITE = 2'b01,
            READ  = 2'b10,
            WAIT  = 2'b11;

// Internal wires for timer slave responses — avoids driving the module's own input ports
wire        timer_pready_w, timer_pslverr_w;
wire [31:0] timer_prdata_w;
wire        timer_irq_w;

timer timer_u (
    clk, resetn, pclk, presetn, psel[2], penable, pwrite, paddr, pwdata,
    timer_prdata_w, timer_pready_w, timer_pslverr_w,
    timer_irq_w, pwm_out0, pwm_out1
);

// Internal wires for GPIO slave responses
wire        gpio_pready_w, gpio_pslverr_w;
wire [31:0] gpio_prdata_w;
wire        gpio_irq_w;

gpio gpio_u (
    .clk(clk), .resetn(resetn),
    .pclk(pclk), .presetn(presetn),
    .psel(psel[3]), .penable(penable), .pwrite(pwrite),
    .paddr(paddr), .pwdata(pwdata),
    .prdata(gpio_prdata_w), .pready(gpio_pready_w), .pslverr(gpio_pslverr_w),
    .irq(gpio_irq_w),
    .gpio_pad(gpio_pad)
);

// Internal wire for UART slave responses
// wire        uart_pready_w, uart_pslverr_w;
// wire [31:0] uart_prdata_w;
// wire        uart_irq_w;

// uart_top uart_u (

// );

// Mux read data and ready from the addressed peripheral
wire        pready_int = psel[2] ? timer_pready_w :
                         psel[3] ? gpio_pready_w  : pready;
wire [31:0] prdata_int = psel[2] ? timer_prdata_w :
                         psel[3] ? gpio_prdata_w  : prdata;

// irq[4]=matrixmul, irq[3]=timer, irq[2]=gpio, irq[1]=uart, irq[0]=qspi
assign irq = {1'b0, timer_irq_w, gpio_irq_w, 2'b00};

reg [1:0] state;
reg [4:0] periph_sel; // 4-matrixmul, 3-timer, 2-gpio, 1-uart, 0-qspi
reg       just_done;  // blocks re-trigger for one cycle after a transaction completes

// address decoder for peripheral selection
always @(*) begin
    if (cpu_paddr >= 32'h0000_2000 && cpu_paddr < 32'h0000_2040) begin
        periph_sel = 5'b00001; // qspi
    end else if (cpu_paddr >= 32'h0000_2040 && cpu_paddr < 32'h0000_2080) begin
        periph_sel = 5'b00010; // uart
    end else if (cpu_paddr >= 32'h0000_2080 && cpu_paddr < 32'h0000_20C0) begin
        periph_sel = 5'b00100; // timer
    end else if (cpu_paddr >= 32'h0000_20C0 && cpu_paddr < 32'h0000_2100) begin
        periph_sel = 5'b01000; // GPIO
    end else if (cpu_paddr >= 32'h0000_2100 && cpu_paddr < 32'h0000_2400) begin
        periph_sel = 5'b10000; // matrixmul
    end else begin
        periph_sel = 5'b00000; // no peripheral selected
    end
end

// psel
// 4-matrixmul, 3-timer, 2-gpio, 1-uart, 0-qspi
always @(posedge clk) begin
    if (!resetn) begin
        paddr  <= 32'hFFFF_FFFF; psel  <= 5'b0; penable <= 1'b0;
        pwrite <= 1'b0;  pwdata <= 32'b0; state <= IDLE;
        stall  <= 1'b0;  just_done <= 1'b0; cpu_rdata <= 32'b0;
    end else begin
        just_done <= 1'b0; // default: clear each cycle
        case (state)
            IDLE: begin
                // Only start a transaction when a peripheral is addressed AND we didn't
                // just finish one (just_done prevents re-triggering before CPU advances)
                if (|periph_sel && !just_done) begin
                    paddr   <= cpu_paddr;
                    pwdata  <= cpu_wdata;
                    psel    <= periph_sel;
                    pwrite  <= write;
                    penable <= 1'b0; // APB setup phase: psel=1, penable=0
                    stall   <= 1'b1; // hold CPU
                    state   <= write ? WRITE : READ;
                end else begin
                    stall   <= 1'b0;
                    psel    <= 5'b0;
                    penable <= 1'b0;
                end
            end
            // WRITE/READ run unconditionally — not gated by periph_sel so they
            // cannot get stuck if cpu_paddr changes while the transaction runs
            WRITE: begin
                penable <= 1'b1;
                if (pready_int) begin
                    penable   <= 1'b0;
                    psel      <= 5'b0;
                    stall     <= 1'b0;  // release CPU; it will advance on next posedge
                    just_done <= 1'b1;  // block re-trigger for that one cycle
                    state     <= IDLE;
                end
            end
            READ: begin
                penable <= 1'b1;
                if (pready_int) begin
                    cpu_rdata <= prdata_int; // latch peripheral read data while psel/penable still high
                    penable   <= 1'b0;
                    psel      <= 5'b0;
                    stall     <= 1'b0;
                    just_done <= 1'b1;
                    state     <= IDLE;
                end
            end
        endcase
    end
end

endmodule