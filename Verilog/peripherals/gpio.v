// gpio.v - GPIO peripheral for RISC-V SoC
// 32-bit bidirectional GPIO with direction control and interrupts
// Registers:
// GDIR - GPIO Direction Register         addr BASE + 0x00  (1=output, 0=input per bit)
// GDAT - GPIO Data Register              addr BASE + 0x04  (write: drive output, read: pin state)
// GIEN - GPIO Interrupt Enable Register  addr BASE + 0x08  (1=interrupt enabled for pin)
// GIRQ - GPIO Interrupt Flag Register    addr BASE + 0x0C  (read-to-clear, 1=edge detected)

module gpio #(
    parameter BASE_ADDR = 32'h0000_20C0
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

    // GPIO pads (split for synthesis)
    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out,
    output wire [31:0] gpio_oe
);

localparam GDIR_ADDR = BASE_ADDR;           // BASE + 0x00
localparam GDAT_ADDR = BASE_ADDR + 32'h4;   // BASE + 0x04
localparam GIEN_ADDR = BASE_ADDR + 32'h8;   // BASE + 0x08
localparam GIRQ_ADDR = BASE_ADDR + 32'hC;   // BASE + 0x0C

reg [31:0] GDIR; // direction: 1=output
reg [31:0] GDAT; // output data
reg [31:0] GIEN; // interrupt enable: 1=enabled
reg [31:0] GIRQ; // interrupt flags (read-to-clear)
reg [31:0] gpio_in_prev; // previous input state for edge detection

// Combinational edge detection
wire [31:0] gpio_edge = gpio_in ^ gpio_in_prev;
wire [31:0] enabled_edges = gpio_edge & GIEN & ~GDIR;

// Drive signals — IOBUFs instantiated in soc_top
assign gpio_out = GDAT;
assign gpio_oe  = GDIR;

always @(posedge clk) begin // apb write
    if (!resetn) begin
        GDIR <= 32'b0; GDAT <= 32'b0; GIEN <= 32'b0; pslverr <= 1'b0;
    end else if (psel && penable && pwrite) begin
        pslverr <= 1'b0; // clear error by default
        case (paddr)
            GDIR_ADDR: GDIR <= pwdata;
            GDAT_ADDR: GDAT <= pwdata & GDIR; // only update output bits
            GIEN_ADDR: GIEN <= pwdata;        // interrupt enable
            default:   pslverr <= 1'b1;
        endcase
    end
end

always @(*) begin // apb read
    if (psel && penable && !pwrite) begin
        case (paddr)
            GDIR_ADDR: prdata = GDIR;
            GDAT_ADDR: prdata = gpio_in;  // read pin state, not output register
            GIEN_ADDR: prdata = GIEN;
            GIRQ_ADDR: prdata = GIRQ;     // read returns current flags
            default:   prdata = 32'b0;
        endcase
    end else begin
        prdata = 32'b0;
    end
end

assign pready = (psel && penable) ? 1'b1 : 1'b0;

// GIRQ management and IRQ generation
always @(posedge clk) begin
    if (!resetn) begin
        GIRQ <= 32'b0;
        gpio_in_prev <= 32'b0;
        irq <= 1'b0;
    end else begin
        // Update previous state for next cycle
        gpio_in_prev <= gpio_in;

        // Generate single-cycle IRQ pulse
        irq <= |enabled_edges;

        // Clear GIRQ when read
        if (psel && penable && !pwrite && paddr == GIRQ_ADDR) begin
            GIRQ <= 32'b0;
        end else begin
            // Accumulate edge events
            GIRQ <= GIRQ | enabled_edges;
        end
    end
end

endmodule