`timescale 1 ns/1 ns

// Test the RISC-V processor for pipelined cpu
// load rv32i_test.hex in instr_mem.v
module tb_pl;

// registers to send data
reg clk;
reg reset;
reg Ext_MemWrite;
reg [31:0] Ext_WriteData, Ext_DataAdr;

// Wire Outputs from Instantiated Modules
wire [31:0] WriteData, DataAdr, ReadData;
wire MemWrite;
wire [31:0] PCW, Result, DataAdrW, WriteDataW, ReadDataW;

// Initialize Top Module
riscv_cpu uut (clk, reset, 5'b0, Ext_MemWrite, Ext_WriteData, Ext_DataAdr, MemWrite, WriteData,
               DataAdr, ReadData, PCW, Result, DataAdrW, WriteDataW, ReadDataW);

integer fault_instrs = 0, i = 0, flag = 0;
reg [31:0] last_pcw = 32'hFFFFFFFF; // guard: only check once per unique PCW

localparam ADDI_x0  =   32'h8;
localparam ADDI     =   32'h10;
localparam SLLI     =   32'h14;
localparam SLTI     =   32'h18;
localparam SLTIU    =   32'h1C;
localparam XORI     =   32'h20;
localparam SRLI     =   32'h24;
localparam SRAI     =   32'h28;
localparam ORI      =   32'h2C;
localparam ANDI     =   32'h30;

localparam ADD      =   32'h34;
localparam SUB      =   32'h38;
localparam SLL      =   32'h3C;
localparam SLT      =   32'h40;
localparam SLTU     =   32'h44;
localparam XOR      =   32'h48;
localparam SRL      =   32'h4C;
localparam SRA      =   32'h50;
localparam OR       =   32'h54;
localparam AND      =   32'h58;

localparam LUI      =   32'h5C;
localparam AUIPC    =   32'h60;

localparam SB       =   32'h64;
localparam SH       =   32'h68;
localparam SW       =   32'h6C;

localparam LB       =   32'h70;
localparam LH       =   32'h74;
localparam LW       =   32'h78;
localparam LBU      =   32'h7C;
localparam LHU      =   32'h80;

localparam BLT_IN   =   32'h90;
localparam BLT_OUT  =   32'h9C;
localparam BGE_IN   =   32'hAC;
localparam BGE_OUT  =   32'hB8;
localparam BLTU_IN  =   32'hC8;
localparam BLTU_OUT =   32'hD4;
localparam BGEU_IN  =   32'hE4;
localparam BGEU_OUT =   32'hF0;
localparam BNE_IN   =   32'h100;
localparam BNE_OUT  =   32'h10C;
localparam BEQ_IN   =   32'h11C;
localparam BEQ_OUT  =   32'h128;

localparam JALR     =   32'h134;
localparam MUL      =   32'h140;
localparam MULH     =   32'h144;
localparam MULHU    =   32'h148;
localparam MULHSU   =   32'h14C;
localparam DIV      =   32'h150;
localparam DIVU     =   32'h154;
localparam REM      =   32'h158;
localparam REMU     =   32'h15C;
localparam JAL      =   32'h160;

// ALU / computation result check
task check_alu;
    input integer    num;
    input [20*8-1:0] name;
    input [31:0]     expected;
    begin
        if (Result === expected) begin
            i = i + 1;
            $display("%0d. %0s passed", num, name);
        end else begin
            $display("%0d. %0s FAILED | PC=0x%h  Result=%0d  Expected=%0d",
                     num, name, PCW, $signed(Result), $signed(expected));
            fault_instrs = fault_instrs + 1;
        end
    end
endtask

// Store check: Result = computed address, WriteDataW = data written
// guard_mw=1 : also require (MemWrite && reset) to be asserted (SB/SH)
// guard_mw=0 : skip MemWrite check (SW)
task check_store;
    input integer    num;
    input [20*8-1:0] name;
    input [31:0]     exp_addr;
    input [31:0]     exp_data;
    input            guard_mw;
    begin
        if ((!guard_mw || (MemWrite && reset)) &&
            Result    === exp_addr &&
            WriteDataW === exp_data) begin
            i = i + 1;
            $display("%0d. %0s passed", num, name);
        end else begin
            $display("%0d. %0s FAILED | PC=0x%h  Addr=%0d(exp %0d)  WriteData=%0d(exp %0d)  MemWrite=%b",
                     num, name, PCW,
                     Result, exp_addr,
                     $signed(WriteDataW), $signed(exp_data),
                     MemWrite);
            fault_instrs = fault_instrs + 1;
        end
    end
endtask

// Load check: DataAdrW = address used, ReadDataW = data read back
task check_load;
    input integer    num;
    input [20*8-1:0] name;
    input [31:0]     exp_addr;
    input [31:0]     exp_data;
    begin
        if (DataAdrW === exp_addr && ReadDataW === exp_data) begin
            i = i + 1;
            $display("%0d. %0s passed", num, name);
        end else begin
            $display("%0d. %0s FAILED | PC=0x%h  Addr=%0d(exp %0d)  ReadData=%0d(exp %0d)",
                     num, name, PCW,
                     DataAdrW, exp_addr,
                     $signed(ReadDataW), $signed(exp_data));
            fault_instrs = fault_instrs + 1;
        end
    end
endtask

// Branch-in-loop watchdog — does NOT increment i.
// Stops simulation if the loop counter exceeds max_val (runaway guard).
task check_loop;
    input integer    num;
    input [20*8-1:0] name;
    input [31:0]     max_val;
    begin
        if (Result <= max_val)
            $display("%0d. %0s executing | PC=0x%h  Result=%0d", num, name, PCW, $signed(Result));
        else begin
            $display("%0d. %0s stuck in loop! | PC=0x%h  Result=%0d  Expected<=%0d",
                     num, name, PCW, $signed(Result), max_val);
            flag = 1;
            $stop;
        end
    end
endtask

// Clock
always begin
    clk <= 0; #8; clk <= 1; #8;
end

initial begin
    $dumpfile("./Verilog/dumps/tb_pl.vcd");
    $dumpvars(0, tb_pl);
    reset = 0;
    Ext_MemWrite = 0; Ext_DataAdr = 32'b0; Ext_WriteData = 32'b0; #12;
    reset = 1;

    #10000;
    $display("Worst Case simulation time reached, Problem with the design :(");
    $finish;
end

always @(posedge clk) begin
    if (PCW !== last_pcw) begin
        last_pcw <= PCW;
        case (PCW)
        ADDI_x0  : check_alu  ( 1, "addi x0",     -3           );
        ADDI     : check_alu  ( 2, "addi",          9          );
        SLLI     : check_alu  ( 3, "slli",         64          );
        SLTI     : check_alu  ( 4, "slti",          0          );
        SLTIU    : check_alu  ( 5, "sltiu",         1          );
        XORI     : check_alu  ( 6, "xori",          2          );
        SRLI     : check_alu  ( 7, "srli",  536870911          );
        SRAI     : check_alu  ( 8, "srai",         -1          );
        ORI      : check_alu  ( 9, "ori",          -1          );
        ANDI     : check_alu  (10, "andi",          1          );
        ADD      : check_alu  (11, "add",          17          );
        SUB      : check_alu  (12, "sub",          15          );
        SLL      : check_alu  (13, "sll",          32          );
        SLT      : check_alu  (14, "slt",           0          );
        SLTU     : check_alu  (15, "sltu",          1          );
        XOR      : check_alu  (16, "xor",          17          );
        SRL      : check_alu  (17, "srl",           8          );
        SRA      : check_alu  (18, "sra",           8          );
        OR       : check_alu  (19, "or",           17          );
        AND      : check_alu  (20, "and",           0          );
        LUI      : check_alu  (21, "lui",   32'h02000000       );
        AUIPC    : check_alu  (22, "auipc", 32'h02000060       );
        SB       : check_store(23, "sb",   33,   1,      1'b1  );
        SH       : check_store(24, "sh",   38,  -3,      1'b1  );
        SW       : check_store(25, "sw",   40,  16,      1'b0  );
        LB       : check_load (26, "lb",   33,   1             );
        LH       : check_load (27, "lh",   38,  -3             );
        LW       : check_load (28, "lw",   40,  16             );
        LBU      : check_load (29, "lbu",  33,   1             );
        LHU      : check_load (30, "lhu",  38, 32'h0000FFFD    );
        BLT_IN   : check_loop (31, "blt",  32'hA               );
        BLT_OUT  : check_alu  (31, "blt",   5                  );
        BGE_IN   : check_loop (32, "bge",  32'hB               );
        BGE_OUT  : check_alu  (32, "bge",  -6                  );
        BLTU_IN  : check_loop (33, "bltu",  4                  );
        BLTU_OUT : check_alu  (33, "bltu",  5                  );
        BGEU_IN  : check_loop (34, "bgeu",  5                  );
        BGEU_OUT : check_alu  (34, "bgeu",  0                  );
        BNE_IN   : check_loop (35, "bne",   5                  );
        BNE_OUT  : check_alu  (35, "bne",   5                  );
        BEQ_IN   : check_loop (36, "beq",   2                  );
        BEQ_OUT  : check_alu  (36, "beq",   4                  );
        JALR     : check_alu  (37, "jalr", 32'h130             );
        MUL      : check_alu  (38, "mul",    -108              );
        MULH     : check_alu  (39, "mulh",   -1                );
        MULHU    : check_alu  (40, "mulhu",  -12               );
        MULHSU   : check_alu  (41, "mulhsu", -1                );
        DIV      : check_alu  (42, "div",     0                );
        DIVU     : check_alu  (43, "divu",    238609293        );
        REM      : check_alu  (44, "rem",     -6               );
        REMU     : check_alu  (45, "remu",    16               );
        JAL      : check_alu  (46, "jal",  32'h164             );
        endcase
    end // if (PCW !== last_pcw)
end

always @(negedge clk) begin
    if (i >= 46 || flag == 1) begin
        $display("Faulty Instructions => %d", fault_instrs);
        $finish;
    end
end

endmodule