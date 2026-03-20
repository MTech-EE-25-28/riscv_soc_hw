
module csr_handler (
    input         clk, reset, ivalid,

    input         csr_write_en,
    input  [11:0] csr_addr,
    input  [31:0] csr_write_data,
    output reg [31:0] csr_read_data
);

localparam  CSR_MSTATUS  = 12'h300,
            CSR_MISA     = 12'h301,
            CSR_MIE      = 12'h304,
            CSR_MTVEC    = 12'h305,
            CSR_MSTATUSH = 12'h310,
            CSR_MSCRATCH = 12'h340,
            CSR_MEPC     = 12'h341,
            CSR_MCAUSE   = 12'h342,
            CSR_MTVAL    = 12'h343,
            CSR_MIP      = 12'h344,
            CSR_MTINST   = 12'h345,
            CSR_MTVAL2   = 12'h346,
            CSR_MCYCLEL  = 12'hB00,
            CSR_INSTRETL = 12'hB02,
            CSR_MCYCLEH  = 12'hB80,
            CSR_INSTRETH = 12'hB82;

reg [63:0] cycle_counter, instret_counter;

// instruction retired counter
always @(posedge clk) begin
    if (!reset)
        instret_counter <= 64'b0;
    else if (ivalid)
        instret_counter <= instret_counter + 1'b1;
end
// cycle counter
always @(posedge clk) begin
    if (!reset)
        cycle_counter <= 64'b0;
    else
        cycle_counter <= cycle_counter + 1'b1;
end

always @(*) begin
    if (!reset) begin
        csr_read_data = 32'b0;
    end else begin
        case (csr_addr)
            CSR_MISA    : csr_read_data = {2'b01, 4'b000, 26'h0001100};
            CSR_MCYCLEH : csr_read_data = cycle_counter[63:32];
            CSR_MCYCLEL : csr_read_data = cycle_counter[31:0];
            CSR_INSTRETH: csr_read_data = instret_counter[63:32];
            CSR_INSTRETL: csr_read_data = instret_counter[31:0];
            default:      csr_read_data = 32'b0; // For unsupported CSRs, return 0
        endcase
    end
end

endmodule