
module csr_handler (
    input         clk, reset, ivalid,

    input         csr_write_en,
    input  [ 1:0] csr_type,
    input  [11:0] csr_addr,
    input  [31:0] csr_write_data, // data from rs1
    output [31:0] csr_read_data,

    // trap handler
    input         trap, trap_mstatus_mie, trap_mstatus_mpie,
    input  [31:0] trap_mepc, trap_mcause, trap_mtval,

    // trap return handler
    input        tret, tret_mstatus_mie, tret_mstatus_mpie,

    // csr fields
    output  [31:0] csr_mstatus, csr_mie, csr_mip, csr_mtvec,
    output  [31:0] csr_mepc, csr_mcause, csr_mscratch, csr_mtval
);

localparam  MSTATUS  = 12'h300,
            MISA     = 12'h301,
            MIE      = 12'h304,
            MTVEC    = 12'h305,
            MSCRATCH = 12'h340,
            MEPC     = 12'h341,
            MCAUSE   = 12'h342,
            MTVAL    = 12'h343,
            MIP      = 12'h344,
            MCYCLEL  = 12'hB00,
            INSTRETL = 12'hB02,
            MCYCLEH  = 12'hB80,
            INSTRETH = 12'hB82,
            TIMECMPL = 12'h7C0,
            TIMECMPH = 12'h7C1;

reg [31:0] mstatus, mie, mtvec, mscratch, mepc, mcause, mtval, mip;
reg [63:0] cycle_counter, instret_counter;
reg [31:0] csr_prev_value, csr_curr_value;

// Machine timer compare registers (CLINT-style, but in CSR space)
reg [31:0] timecmp_h, timecmp_l;
wire [63:0] timecmp = {timecmp_h, timecmp_l};

// Machine timer interrupt pending - fires when cycle_counter >= timecmp
// The actual interrupt enable check (mie.MTIE && mstatus.MIE) is done in trap_handler
wire mtip = (cycle_counter >= timecmp);

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
        csr_prev_value = 32'b0; csr_curr_value = 32'b0;
    end else begin
        case (csr_addr)
            MISA    : csr_prev_value = {2'b01, 4'b000, 26'h0001100};
            MCYCLEH : csr_prev_value = cycle_counter[63:32];
            MCYCLEL : csr_prev_value = cycle_counter[31:0];
            INSTRETH: csr_prev_value = instret_counter[63:32];
            INSTRETL: csr_prev_value = instret_counter[31:0];
            MSTATUS : csr_prev_value = mstatus;
            MIE     : csr_prev_value = mie;
            MTVEC   : csr_prev_value = mtvec;
            MSCRATCH: csr_prev_value = mscratch;
            MEPC    : csr_prev_value = mepc;
            MCAUSE  : csr_prev_value = mcause;
            MTVAL   : csr_prev_value = mtval;
            MIP     : csr_prev_value = mip;
            TIMECMPL: csr_prev_value = timecmp_l;
            TIMECMPH: csr_prev_value = timecmp_h;
            default:  csr_prev_value = 32'b0; // For unsupported CSRs, return 0
        endcase
        case (csr_type)  // InstrE[13:12]: CSRRW/I=01  CSRRS/I=10  CSRRC/I=11
            2'b01: csr_curr_value = csr_write_data;                    // CSRRW/CSRRWI: overwrite
            2'b10: csr_curr_value = csr_prev_value | csr_write_data;   // CSRRS/CSRRSI: set bits
            2'b11: csr_curr_value = csr_prev_value & ~csr_write_data;  // CSRRC/CSRRCI: clear bits
            default: csr_curr_value = csr_prev_value; // 2'b00: ecall/ebreak/mret — no write
        endcase
    end
end

// write csr
// mstatus concerned bits to update: MIE (3), MPIE (7), MPP (12-11)
// initialize mstatus with MPP=11 (machine previous previlege) no other mode supported.
always @(posedge clk) begin
    if (!reset) begin
        mie <= 32'b0; mtvec <= 32'b0; mepc <= 32'b0;
        mip <= 32'b0; mtval <= 32'b0; mscratch <= 32'b0;
        mstatus <= {19'b0, 2'b11, 11'b0};
        mcause  <= 32'b0;
        timecmp_h <= 32'hFFFF_FFFF;  // Initialize to max (no timer interrupt)
        timecmp_l <= 32'hFFFF_FFFF;
    end else begin
        if (trap) begin
            mepc <= {trap_mepc[31:2], 2'b00};
            mcause <= trap_mcause;
            mtval <= trap_mtval;
            mstatus <= {19'b0, 2'b11, 3'b0, trap_mstatus_mpie, 3'b0, trap_mstatus_mie, 3'b0};
        end else if (tret) begin
            mstatus <= {19'b0, 2'b11, 3'b0, tret_mstatus_mpie, 3'b0, tret_mstatus_mie, 3'b0};
        end else begin
            // Update mip: set MTIP (bit 7) based on timer, preserve other bits
            mip <= {24'b0, mtip, 7'b0};  // Only bit 7 (MTIP) is set by hardware
        end

        if (csr_write_en && ivalid) begin  // gate writes on ivalid to prevent spurious commits on FlushE
        case (csr_addr)
                // write based on correct masking of bits for each csr
                MSTATUS : mstatus  <= (csr_prev_value & 32'hFFFF_FF00) | (csr_curr_value & 32'h0000_0088); // only MIE[3] and MPIE[7] writable
                MIE     : mie      <= csr_curr_value & 32'h0000_0088; // Allow MTIE[7] and MEIE[3]
                MTVEC   : mtvec    <= (csr_curr_value & 32'hFFFF_FFFD); // [31:2]=base, [1]=0 (only modes 0/1 valid), [0]=mode
                MSCRATCH: mscratch <= csr_curr_value; // no reserved bits
                MEPC    : mepc     <= (csr_prev_value & 32'h0000_0000) | (csr_curr_value & 32'hFFFF_FFFC); // 31:2 - Trap program counter, 4bytes aligned
                MCAUSE  : mcause   <= (csr_prev_value & 32'hFFFF_FC00) | (csr_curr_value & 32'h0000_03FF); // 9:0 - mcause should lie within it.
                MTVAL   : mtval    <= csr_curr_value; // no reserved bits
                TIMECMPL: timecmp_l <= csr_curr_value;
                TIMECMPH: timecmp_h <= csr_curr_value;
                default: /* do nothing for unsupported CSRs */ ;
            endcase
        end
    end
end

// read csr
assign csr_read_data = csr_prev_value;

// for trap handling
assign csr_mstatus  = mstatus;
assign csr_mie      = mie;
assign csr_mip      = mip;
assign csr_mtvec    = mtvec;
assign csr_mepc     = mepc;
assign csr_mcause   = mcause;
assign csr_mtval    = mtval;
assign csr_mscratch = mscratch;

endmodule