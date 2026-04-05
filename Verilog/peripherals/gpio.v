// gpio.v - GPIO peripheral for RISC-V SoC
// 32-bit bidirectional GPIO with direction control
// Registers:
// GDIR - GPIO Direction Register   addr BASE + 0x04  (1=output, 0=input per bit)
// GDAT - GPIO Data Register        addr BASE + 0x08  (write: drive output, read: pin state)

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
    output reg         pready,
    output reg         pslverr,

    // Interrupt
    output reg         irq,

    // GPIO pads
    inout  wire [31:0] gpio_pad
);

localparam GDIR_ADDR = BASE_ADDR;           // BASE + 0x00
localparam GDAT_ADDR = BASE_ADDR + 32'h4;   // BASE + 0x04

reg [31:0] GDIR; // direction: 1=output
reg [31:0] GDAT; // output data

// Tristate drive: output when GDIR[i]=1, Hi-Z when input
genvar i;
generate
    for (i = 0; i < 32; i = i + 1) begin : GPIO_TRISTATE
        assign gpio_pad[i] = GDIR[i] ? GDAT[i] : 1'bz;
    end
endgenerate

always @(posedge clk) begin // apb write
    if (!resetn) begin
        GDIR <= 32'b0; GDAT <= 32'b0; pslverr <= 1'b0;
    end else if (psel && penable && pwrite) begin
        case (paddr)
            GDIR_ADDR: GDIR <= pwdata;
            GDAT_ADDR: GDAT <= pwdata & GDIR; // only update output bits
            default:   pslverr <= 1'b1;
        endcase
    end
end

always @(*) begin // apb read
    if (psel && penable && !pwrite) begin
        case (paddr)
            GDIR_ADDR: prdata = GDIR;
            GDAT_ADDR: prdata = gpio_pad; // read pin state, not output register
            default:   prdata = 32'b0;
        endcase
    end else begin
        prdata = 32'b0;
    end
end

assign pready = (psel && penable) ? 1'b1 : 1'b0;

always @(posedge clk) begin // irq on any input pin change (edge detect)
    if (!resetn) begin
        irq <= 1'b0;
    end else begin
        // need to add edge detection to generate an interrupt for only one pin
        irq <= 1'b0;
    end
end

endmodule