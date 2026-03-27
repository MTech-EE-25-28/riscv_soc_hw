
module csr_handler (
    input         clk, reset, ivalid,

    input         csr_write_en,
    input  [ 1:0]  csr_type,
    input  [11:0] csr_addr,
    input  [31:0] csr_write_data, // data from rs1
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

reg [31:0] mstatus, mscratch, mepc, mcause, mtval, mip, mtinst, mtval2;
reg [63:0] cycle_counter, instret_counter;
reg [31:0] csr_prev_value;

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

// get previous csr value
always @(*) begin
    if (!reset) begin
        csr_prev_value = 32'b0;
    end else begin
        case (csr_addr)
            CSR_MISA    : csr_prev_value = {2'b01, 4'b000, 26'h0001100};
            CSR_MCYCLEH : csr_prev_value = cycle_counter[63:32];
            CSR_MCYCLEL : csr_prev_value = cycle_counter[31:0];
            CSR_INSTRETH: csr_prev_value = instret_counter[63:32];
            CSR_INSTRETL: csr_prev_value = instret_counter[31:0];
            CSR_MSTATUS : csr_prev_value = mstatus;
            CSR_MSCRATCH: csr_prev_value = mscratch;
            CSR_MEPC    : csr_prev_value = mepc;
            CSR_MCAUSE  : csr_prev_value = mcause;
            CSR_MTVAL   : csr_prev_value = mtval;
            CSR_MIP      : csr_prev_value = mip;
            CSR_MTINST   : csr_prev_value = mtinst;
            CSR_MTVAL2   : csr_prev_value = mtval2;
            default:      csr_prev_value = 32'b0; // For unsupported CSRs, return 0
        endcase
    end
end

// write csr
always @(negedge clk) begin
    if (!reset) begin
        mstatus <= 32'b0; mscratch <= 32'b0; mepc <= 32'b0;
        mcause <= 32'b0; mtval <= 32'b0; mip <= 32'b0;
        mtinst <= 32'b0; mtval2 <= 32'b0;
    end else if (csr_write_en) begin
        case (csr_addr)
            CSR_MSTATUS: begin
                mstatus <= csr_write_data;
            end
            // CSR_MIE: begin
            // end
            // CSR_MTVEC: begin
            // end
            // CSR_MSCRATCH: begin
            // end
            // CSR_MEPC: begin
            // end
            // CSR_MCAUSE: begin
            // end
            // CSR_MTVAL: begin
            // end
            // CSR_MIP: begin
            // end
            // CSR_MTINST: begin
            // end
            // CSR_MTVAL2: begin
            // end
        endcase
    end
end

// read csr
always @(*) begin
    case (csr_type)
        2'b00: csr_read_data = csr_prev_value; // read current value before write
        2'b01: csr_read_data = csr_prev_value | csr_write_data; // set bits
        2'b10: csr_read_data = csr_prev_value & ~csr_write_data; // clear bits
        default: csr_read_data = 32'b0;
    endcase
end

endmodule