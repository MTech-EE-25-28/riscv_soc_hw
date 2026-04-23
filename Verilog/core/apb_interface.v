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

    // bootload mem
    output wire        write_mem,
    output wire [31:0] instr_addr,
    output wire [31:0] instr_write,

    // Peripheral interface
    input  wire        boot_select,
    output wire        cpu_resetn,
    output wire  [4:0] irq,
    // Pads
    output wire        pwm_out0, pwm_out1, pwm_out2,
    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out,
    output wire [31:0] gpio_oe,
    input  wire        rx,
    output wire        tx,
    input  wire [3:0]  qspi_io_in,
    output wire [3:0]  qspi_io_out,
    output wire        qspi_io_oe,
    output wire        qspi_sck,
    output wire        qspi_cs_n
);

localparam  IDLE  = 2'b00,
            WRITE = 2'b01,
            READ  = 2'b10,
            WAIT  = 2'b11;

// Bootloader instantiation
wire uart_boot, uart_boot_en, uart_boot_wr, uart_boot_ready, uart_boot_slverr, uart_boot_resetn;
wire [31:0] uart_boot_addr, uart_boot_wdata;
wire [31:0] uart_boot_rdata;

boot_loader bootloader_u (
    .clk(clk), .resetn(resetn),
    .boot_select(boot_select), .cpu_resetn(cpu_resetn), .presetn(uart_boot_resetn),
    .psel(uart_boot), .penable(uart_boot_en), .pwrite(uart_boot_wr),
    .paddr(uart_boot_addr), .pwdata(uart_boot_wdata),
    .prdata(uart_boot_rdata), .pready(uart_boot_ready), .pslverr(uart_boot_slverr),

    .write_data_en(write_mem), .out_send_data(instr_write), .out_send_addr(instr_addr)
);

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
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_oe(gpio_oe)
);

// Internal wires for timer slave responses — avoids driving the module's own input ports
wire        timer_pready_w, timer_pslverr_w;
wire [31:0] timer_prdata_w;
wire        timer_irq_w;

timer timer_u (
    .clk(clk), .resetn(resetn),
    .pclk(pclk), .presetn(presetn),
    .psel(psel[2]), .penable(penable), .pwrite(pwrite),
    .paddr(paddr), .pwdata(pwdata),
    .prdata(timer_prdata_w), .pready(timer_pready_w), .pslverr(timer_pslverr_w),
    .irq(timer_irq_w), .pwm_out0(pwm_out0), .pwm_out1(pwm_out1), .pwm_out2(pwm_out2)
);

// Internal wire for UART slave responses
wire        uart_pready_w, uart_pslverr_w;
wire [31:0] uart_prdata_w;

// Feed uart_top response back to bootloader (boot_loader ignores pready/pslverr)
assign uart_boot_rdata = uart_prdata_w;

// choose between bootloader or regular UART based on boot_select
wire uart_sel = !cpu_resetn ? uart_boot : psel[1];
wire uart_pready = !cpu_resetn ? uart_boot_ready : uart_pready_w;
wire [31:0] uart_prdata = !cpu_resetn ? uart_boot_rdata : uart_prdata_w;
wire uart_slverr = !cpu_resetn ? uart_boot_slverr : uart_pslverr_w;
wire uart_penable = !cpu_resetn ? uart_boot_en : penable;
wire uart_write = !cpu_resetn ? uart_boot_wr : pwrite;
wire [31:0] uart_addr = !cpu_resetn ? uart_boot_addr : paddr;
wire [31:0] uart_wdata = !cpu_resetn ? uart_boot_wdata : pwdata;
wire uart_resetn = !cpu_resetn ? uart_boot_resetn : presetn;

uart_top uart_u (
    .pclk(pclk), .presetn(uart_resetn),
    .psel(uart_sel), .penable(uart_penable), .pwrite(uart_write),
    .paddr(uart_addr), .pwdata(uart_wdata),
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
    .paddr(paddr), .pwdata(pwdata),
    .prdata(qspi_prdata_w), .pready(qspi_pready_w), .pslverr(qspi_pslverr_w),
    .io_in(qspi_io_in), .io_out(qspi_io_out), .io_oe(qspi_io_oe),
    .sck(qspi_sck), .cs_n(qspi_cs_n),
    .irq_done(qspi_irq_w)
);

// Mux read data and ready from the addressed peripheral
wire        pready_int = psel[0] ? qspi_pready_w :
                         psel[1] ? uart_pready_w :
                         psel[2] ? timer_pready_w :
                         psel[3] ? gpio_pready_w  :
                         psel[4] ? mm_pready_w    : 1'b1;

wire [31:0] prdata_int = psel[0] ? qspi_prdata_w :
                         psel[1] ? uart_prdata_w :
                         psel[2] ? timer_prdata_w :
                         psel[3] ? gpio_prdata_w  :
                         psel[4] ? mm_prdata_w    : 32'b0;

// irq[4]=matrixmul, irq[3]=timer, irq[2]=gpio, irq[1]=uart, irq[0]=qspi
assign irq = {1'b0, timer_irq_w, gpio_irq_w, 1'b0, 1'b0};

reg [1:0] state;
reg [4:0] periph_sel; // 4-matrixmul, 3-timer, 2-gpio, 1-uart, 0-qspi
reg [4:0] periph_sel_r;
reg       txn_done_r; // one-cycle lockout after WAIT to prevent re-trigger on stale DataAdr

// Register apb_done to break the long combo path:
//   state reg → (state==WAIT) → apb_done → hazard_unit → MemStall → pipeline enables
// In post-implementation timing this path doesn't close at 50 MHz.
// Registering adds 1 extra stall cycle (20 ns) per peripheral access — negligible vs baud periods.
// apb_done_reg goes high in the IDLE cycle after WAIT, same cycle as txn_done_r=1,
// so both signals are perfectly synchronised and the pipeline releases cleanly.
reg apb_done_reg;
assign apb_done = apb_done_reg;

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
        paddr  <= 32'b0; psel  <= 5'b0; penable <= 1'b0;
        pwrite <= 1'b0;  pwdata <= 32'b0; state <= IDLE;
        cpu_rdata <= 32'b0;
        periph_sel_r <= 5'b0;
        txn_done_r   <= 1'b0;
        apb_done_reg <= 1'b0;
    end else begin
        txn_done_r   <= (state == WAIT); // high for exactly 1 cycle after WAIT→IDLE
        apb_done_reg <= (state == WAIT); // registered apb_done: high in IDLE cycle after WAIT
        case (state)
            IDLE: begin
                if (|periph_sel && !txn_done_r) begin
                    periph_sel_r <= periph_sel;
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
                    state   <= WAIT;
                end
            end
            READ: begin
                penable <= 1'b1;
                if (pready_int) begin
                    cpu_rdata <= prdata_int;
                    state     <= WAIT;
                end
            end
            // WAIT: apb_done pulses high (combinational) this cycle.
            // soc.v: MemStall = ph_stall && !apb_done => drops to 0 this cycle,
            // allowing pl_reg_m to advance at the posedge.  Next cycle cpu_paddr
            // carries the NEW address, so no re-trigger on the old address.
            WAIT: begin
                state <= IDLE;
                penable   <= 1'b0;
                psel      <= 5'b0;
            end
        endcase
    end
end

endmodule