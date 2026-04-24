
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
// [0] - spi, [1] - uart, [2] - gpio, [3] - timer, [4] - matrix multiplier, [5] - machine timer (MTIP)
// tret: MRET detected in decode, propagated to WB.
module trap_handler (
    input  [5:0]  exception,    // see encoding above
    input  [5:0]  interrupt,    // see encoding above
    input         tret,         // MRET
    input  [31:0] pc, pc_m, pc_e, // WB, MEM, EX stage PCs
    input         valid_m,         // valid bit for M-stage
    input         valid_e,         // valid bit for E-stage
    input         wfi_e, wfi_m,    // WFI in E or M stage (for mepc adjustment)
    input  [31:0] mem_addr,        // load/store address misalignment mtval

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
    trap             = 1'b0;  pc_next           = pc + 4; // defaults
    tret_mstatus_mie = 1'b0;  tret_mstatus_mpie = 1'b0;
    trap_mstatus_mie = 1'b0;  trap_mstatus_mpie = 1'b0;
    trap_mepc        = 32'b0; trap_mcause       = 32'b0; trap_mtval = 32'b0;

    if (|exception) begin
        trap              = 1'b1;
        trap_mstatus_mpie = csr_mstatus_mie; // MPIE <- MIE before disabling
        trap_mstatus_mie  = 1'b0;            // MIE disabled on trap entry
        trap_mepc         = {pc[31:2], 2'b00};
        pc_next           = {csr_mtvec[31:2], 2'b00}; // direct/vectored base

        // Priority: illegal > fetch-misalign > ecall > ebreak > load-misalign > store-misalign
        if (exception[0]) begin // illegal instruction
            trap_mcause = 32'd2; trap_mtval  = 32'b0;
        end else if (exception[1]) begin // instruction-address misaligned
            trap_mcause = 32'd0; trap_mtval  = pc;
        end else if (exception[2]) begin // ecall from M-mode
            trap_mcause = 32'd11; trap_mtval  = 32'b0;
        end else if (exception[3]) begin // ebreak (breakpoint)
            trap_mcause = 32'd3; trap_mtval  = 32'b0;
        end else if (exception[4]) begin // load address misaligned
            trap_mcause = 32'd4; trap_mtval  = mem_addr;
        end else begin // store/AMO address misaligned
            trap_mcause = 32'd6; trap_mtval  = mem_addr;
        end

    end else if (csr_mstatus_mie && |interrupt) begin
        // Take interrupt regardless of pipeline bubble in M stage.
        // mepc = earliest in-flight PC: M if valid, else E (first instruction
        // squashed by the flush that caused the M-stage bubble, e.g. loop branch).
        // For WFI: mepc should be PC+4 (next instruction after WFI), not WFI's PC
        trap              = 1'b1;
        trap_mstatus_mpie = csr_mstatus_mie;
        trap_mstatus_mie  = 1'b0;

        // If interrupted instruction is WFI, save PC+4; otherwise save PC
        if (valid_m && wfi_m)
            trap_mepc = {pc_m[31:2], 2'b00} + 32'd4;
        else if (valid_e && wfi_e)
            trap_mepc = {pc_e[31:2], 2'b00} + 32'd4;
        else if (valid_m)
            trap_mepc = {pc_m[31:2], 2'b00};
        else if (valid_e)
            trap_mepc = {pc_e[31:2], 2'b00};
        else
            trap_mepc = {pc[31:2], 2'b00};

        trap_mtval        = 32'b0;

        // Encode platform mcause (bit[31]=1 = interrupt, lower bits = source id)
        // Machine timer interrupt (MTIP) has highest priority (standard interrupt)
        /* */if (interrupt[5]) trap_mcause = {1'b1, 31'd7};  // Machine Timer Interrupt
        else if (interrupt[0]) trap_mcause = {1'b1, 31'd16}; // SPI
        else if (interrupt[1]) trap_mcause = {1'b1, 31'd17}; // UART
        else if (interrupt[2]) trap_mcause = {1'b1, 31'd18}; // GPIO
        else if (interrupt[3]) trap_mcause = {1'b1, 31'd19}; // Timer
        else if (interrupt[4]) trap_mcause = {1'b1, 31'd20}; // matrix mul
        else                   trap_mcause = {1'b1, 31'd0};

        // Vectored mode (mtvec[1:0]==01): jump to base + mcause[4:0]*4 for per-source ISR
        // Direct mode (mtvec[1:0]==00):  jump to base, ISR reads mcause to dispatch
        if (csr_mtvec[1:0] == 2'b01)
            pc_next = {csr_mtvec[31:2], 2'b00} + (trap_mcause[4:0] << 2);
        else
            pc_next = {csr_mtvec[31:2], 2'b00};

    end else if (tret) begin
        trap              = 1'b1;             // flush pipeline
        tret_mstatus_mie  = csr_mstatus_mpie; // MIE <- MPIE on return
        tret_mstatus_mpie = 1'b1;             // MPIE set back to 1
        pc_next           = csr_mepc;
    end
end

endmodule