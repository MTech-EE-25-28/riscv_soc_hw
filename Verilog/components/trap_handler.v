
// RISC-V SoC - Exception Handler
// Sits in Writeback stage for pc commit.
//
// exception encoding (priority: lower index = higher priority):
//   [0] = illegal instruction   (decode)
//   [1] = misaligned instr fetch (decode, from fetch-stage detect)
//   [2] = ecall                 (decode)
//   [3] = ebreak                (decode)
//   [4] = misaligned load       (memory stage detect, propagated to WB)
//   [5] = misaligned store      (memory stage detect, propagated to WB)
//
// interrupt encoding (priority: lower index = higher priority):
// [0] - spi, [1] - uart, [2] - gpio, [3] - matrix multiplier, [4] - timer
// tret: MRET detected in decode, propagated to WB.
module trap_handler (
    input  [5:0]  exception,    // see encoding above
    input  [4:0]  interrupt,    // see encoding above
    input         tret,         // MRET
    input  [31:0] pc,           // trap pc
    input  [31:0] mem_addr,     // load/store address misalignment mtval

    // CSR values needed for trap/return PC and status update
    input  [31:0] csr_mtvec, csr_mepc,
    input         csr_mstatus_mie, csr_mstatus_mpie,

    // Whether a trap/return is taking place (used to flush pipeline & redirect)
    output reg        trap,
    output reg [31:0] pc_next,

    // Feeds to csr_handler trap port
    output reg        trap_mstatus_mie, trap_mstatus_mpie,
    output reg [31:0] trap_mepc, trap_mcause, trap_mtval,

    // Feeds to csr_handler tret port
    output reg        tret_mstatus_mie, tret_mstatus_mpie
);

always @(*) begin
    // defaults
    trap               = 1'b0;
    pc_next            = pc + 4;
    trap_mstatus_mie   = 1'b0;
    trap_mstatus_mpie  = 1'b0;
    trap_mepc          = 32'b0;
    trap_mcause        = 32'b0;
    trap_mtval         = 32'b0;
    tret_mstatus_mie   = 1'b0;
    tret_mstatus_mpie  = 1'b0;

    if (|exception) begin
        trap              = 1'b1;
        trap_mstatus_mpie = csr_mstatus_mie; // MPIE <- MIE before disabling
        trap_mstatus_mie  = 1'b0;            // MIE disabled on trap entry
        trap_mepc         = {pc[31:2], 2'b00};
        pc_next           = {csr_mtvec[31:2], 2'b00}; // direct/vectored base

        // Priority: illegal > fetch-misalign > ecall > ebreak > load-misalign > store-misalign
        if (exception[0]) begin
            // illegal instruction
            trap_mcause = 32'd2;
            trap_mtval  = 32'b0;
        end else if (exception[1]) begin
            // instruction-address misaligned
            trap_mcause = 32'd0;
            trap_mtval  = pc;
        end else if (exception[2]) begin
            // ecall from M-mode
            trap_mcause = 32'd11;
            trap_mtval  = 32'b0;
        end else if (exception[3]) begin
            // ebreak (breakpoint)
            trap_mcause = 32'd3;
            trap_mtval  = 32'b0;
        end else if (exception[4]) begin
            // load address misaligned
            trap_mcause = 32'd4;
            trap_mtval  = mem_addr;
        end else begin
            // store/AMO address misaligned
            trap_mcause = 32'd6;
            trap_mtval  = mem_addr;
        end

    end else if (|interrupt) begin
        trap              = 1'b1;
        trap_mepc         = {pc[31:2], 2'b00};
        trap_mtval        = 32'b0;
        trap_mstatus_mpie = csr_mstatus_mie;
        trap_mstatus_mie  = 1'b0;

        // Encode platform mcause (bit[31]=1 = interrupt, lower bits = source id)
        /* */if (interrupt[0]) trap_mcause = {1'b1, 31'd16}; // SPI
        else if (interrupt[1]) trap_mcause = {1'b1, 31'd17}; // UART
        else if (interrupt[2]) trap_mcause = {1'b1, 31'd18}; // GPIO
        else if (interrupt[3]) trap_mcause = {1'b1, 31'd19}; // Timer
        else if (interrupt[4]) trap_mcause = {1'b1, 31'd20}; // Reserved
        else                   trap_mcause = {1'b1, 31'd0};

        // Vectored mode (mtvec[1:0]==01): jump to base + mcause[4:0]*4 for per-source ISR
        // Direct mode (mtvec[1:0]==00):  jump to base, ISR reads mcause to dispatch
        if (csr_mtvec[1:0] == 2'b01)
            pc_next = {csr_mtvec[31:2], 2'b00} + (trap_mcause[4:0] << 2);
        else
            pc_next = {csr_mtvec[31:2], 2'b00};

    end else if (tret) begin
        trap              = 1'b1; // flush pipeline
        tret_mstatus_mie  = csr_mstatus_mpie; // MIE <- MPIE on return
        tret_mstatus_mpie = 1'b1;             // MPIE set back to 1
        pc_next           = csr_mepc;
    end
end

endmodule