
// AXI APB Interface for CPU-Peripheral Communication
// master
module apb_interface (
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
    input  wire        write,     // 0 - read
    output wire        apb_done,
    output reg  [31:0] cpu_rdata, // captured peripheral read data

    // Peripheral interface
    output wire  [4:0] irq,
    // Pads
    output wire        pwm_out0, pwm_out1,
    inout  wire [31:0] gpio_pad,
    input  wire        rx,
    output wire        tx,
    inout  wire [3:0]  qspi_io,
    output wire        qspi_sck,
    output wire        qspi_cs_n
);

localparam  IDLE  = 2'b00,
            WRITE = 2'b01,
            READ  = 2'b10,
            WAIT  = 2'b11;

// Internal wires for matrix multiplication accelerator slave responses
wire        mm_pready_w, mm_pslverr_w;
wire [31:0] mm_prdata_w;
wire        mm_irq_w;

apb_systolic #(.BASE_ADDR(32'h0000_2100)) mm_u (
    .clk(clk), .resetn(resetn),
    .pclk(pclk), .presetn(presetn),
    .psel(psel[4]), .penable(penable), .pwrite(pwrite),
    .paddr(paddr), .pwdata(pwdata),
    .prdata(mm_prdata_w), .pready(mm_pready_w), .pslverr(mm_pslverr_w),
    .irq(mm_irq_w)
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

// Internal wires for timer slave responses — avoids driving the module's own input ports
wire        timer_pready_w, timer_pslverr_w;
wire [31:0] timer_prdata_w;
wire        timer_irq_w;

timer timer_u (
    clk, resetn, pclk, presetn, psel[2], penable, pwrite, paddr, pwdata,
    timer_prdata_w, timer_pready_w, timer_pslverr_w,
    timer_irq_w, pwm_out0, pwm_out1
);

// Internal wire for UART slave responses
wire        uart_pready_w, uart_pslverr_w;
wire [31:0] uart_prdata_w;

uart_top uart_u (
    .pclk(pclk), .presetn(presetn),
    .psel(psel[1]), .penable(penable), .pwrite(pwrite),
    .paddr(paddr), .pwdata(pwdata),
    .prdata(uart_prdata_w), .pready(uart_pready_w), .pslverr(uart_pslverr_w),
    .rx(rx), .tx(tx)
);

// Internal wire for QSPI slave responses
wire        qspi_pready_w, qspi_pslverr_w;
wire [31:0] qspi_prdata_w;
wire        qspi_irq_w;

qspi_top qspi_u (
    .clk(clk), .resetn(resetn),
    .pclk(pclk), .presetn(presetn),
    .psel(psel[0]), .penable(penable), .pwrite(pwrite),
    .paddr(paddr[7:0]), .pwdata(pwdata),
    .prdata(qspi_prdata_w), .pready(qspi_pready_w), .pslverr(qspi_pslverr_w),
    .io(qspi_io), .sck(qspi_sck), .cs_n(qspi_cs_n),
    .irq_done(qspi_irq_w)
);

// Mux read data and ready from the addressed peripheral
wire        pready_int = psel[2] ? timer_pready_w :
                         psel[3] ? gpio_pready_w  :
                         psel[4] ? mm_pready_w    :
                         psel[1] ? uart_pready_w  : pready;
wire [31:0] prdata_int = psel[2] ? timer_prdata_w :
                         psel[3] ? gpio_prdata_w  :
                         psel[4] ? mm_prdata_w    :
                         psel[1] ? uart_prdata_w  : prdata;

// irq[4]=matrixmul, irq[3]=timer, irq[2]=gpio, irq[1]=uart, irq[0]=qspi
assign irq = {1'b0, timer_irq_w, gpio_irq_w, 2'b00};

reg [1:0] state;
reg [4:0] periph_sel; // 4-matrixmul, 3-timer, 2-gpio, 1-uart, 0-qspi

assign apb_done = (state == WAIT);

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
        cpu_rdata <= 32'b0;
    end else begin
        case (state)
            IDLE: begin
                // ph_stall (from hazard unit) freezes the pipeline combinationally the moment
                if (|periph_sel) begin
                    paddr   <= cpu_paddr;
                    pwdata  <= cpu_wdata;
                    psel    <= periph_sel;
                    pwrite  <= write;
                    penable <= 1'b0; // APB setup phase: psel=1, penable=0
                    state   <= write ? WRITE : READ;
                end else begin
                    psel    <= 5'b0;
                    penable <= 1'b0;
                end
            end
            WRITE: begin
                penable <= 1'b1;
                if (pready_int) begin
                    penable <= 1'b0;
                    psel    <= 5'b0;
                    state   <= WAIT;
                end
            end
            READ: begin
                penable <= 1'b1;
                if (pready_int) begin
                    cpu_rdata <= prdata_int;
                    penable   <= 1'b0;
                    psel      <= 5'b0;
                    state     <= WAIT;
                end
            end
            // WAIT: apb_done pulses high (combinational) this cycle.
            // soc.v: MemStall = ph_stall && !apb_done => drops to 0 this cycle,
            // allowing pl_reg_m to advance at the posedge.  Next cycle cpu_paddr
            // carries the NEW address, so no re-trigger on the old address.
            WAIT: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule