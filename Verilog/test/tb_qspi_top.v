`timescale 1ns/1ps

module tb_qspi_top;

    //--------------------------------------------
    // Clock + Reset
    //--------------------------------------------
    reg clk;
    reg resetn;

    initial begin
        clk = 0;
        forever #40 clk = ~clk;
    end

    initial begin
        resetn = 0;
        #100 resetn = 1;
    end

    //--------------------------------------------
    // APB
    //--------------------------------------------
    reg         psel, penable, pwrite;
    reg  [31:0] paddr, pwdata;
    wire [31:0] prdata;
    wire done;
    //--------------------------------------------
    // QSPI IO
    //--------------------------------------------
    wire       qspi_sck;
    wire       qspi_cs_n;
    // Split QSPI ports (qspi_top.v now uses in/out/oe instead of inout)
    wire [3:0] qspi_io_out;
    wire       qspi_io_oe;
    wire [3:0] qspi_io_in;

    //--------------------------------------------
    // DUT
    //--------------------------------------------
    qspi_top dut (
        .clk       (clk),
        .resetn    (resetn),

        .pclk      (clk),
        .presetn   (resetn),
        .psel      (psel),
        .penable   (penable),
        .pwrite    (pwrite),
        .paddr     (paddr),
        .pwdata    (pwdata),
        .prdata    (prdata),
        .pready    (),
        .pslverr   (),

        .io_in     (qspi_io_in),
        .io_out    (qspi_io_out),
        .io_oe     (qspi_io_oe),
        .cs_n      (qspi_cs_n),
        .sck       (qspi_sck),

        .irq_done  (done)
    );

    //--------------------------------------------
    // APB WRITE
    //--------------------------------------------
    task apb_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge clk); #1;
        psel=1; pwrite=1; penable=0; paddr=addr; pwdata=data;
        @(posedge clk); #1;
        penable=1;
        @(posedge clk); #1;
        psel=0; penable=0;
    end
    endtask

    //--------------------------------------------
    // APB READ
    //--------------------------------------------
    task apb_read(input [31:0] addr);
    begin
        @(posedge clk); #1;
        psel=1; pwrite=0; penable=0; paddr=addr;
        @(posedge clk); #1;
        penable=1;
        @(posedge clk);
        $display("APB READ [%h] = %h", addr, prdata);
        psel=0; penable=0;
    end
    endtask

    //--------------------------------------------
    // Wait until done
    //--------------------------------------------
    task wait_done();
    begin
        wait(done);
        @(posedge clk); #1;
    end
    endtask

    //--------------------------------------------
    // SIMPLE FLASH STUB — drive 0 into DUT's input port (simulates empty flash)
    //--------------------------------------------
    assign qspi_io_in = 4'b0000;

    //--------------------------------------------
    // CONTROL WORD HELPER
    //--------------------------------------------
    function [31:0] CTRL;
        input [3:0] clkdiv;
        input quad;
        begin
            CTRL = (1<<8) | (clkdiv<<4) | (quad<<1) | 1;
        end
    endfunction

    //--------------------------------------------
    // TEST SEQUENCE
    //--------------------------------------------
    initial begin
        $dumpfile("./Verilog/dumps/tb_qspi_top.vcd");
        $dumpvars(0, tb_qspi_top);
        psel=0; penable=0; pwrite=0;
        wait(resetn);

        //----------------------------------------
        // 1) WREN (06h)
        //----------------------------------------
        $display("\n--- TEST WREN (06h) ---");

        apb_write(32'h0000_2004, 32'h06);              // opcode
        apb_write(32'h0000_2000, CTRL(4'd2,0));        // start + enable

        wait_done();

        //----------------------------------------
        // 2) READ STATUS (05h)
        //----------------------------------------
        $display("\n--- TEST RDSR (05h) ---");

        apb_write(32'h0000_2004, 32'h05);
        apb_write(32'h0000_2010, 32'h1);               // length = 1
        apb_write(32'h0000_2000, CTRL(4'd2,0));

        //$finish;
        wait_done();
        apb_read(32'h0000_200C);

        //----------------------------------------
        // 3) READ ID (9Fh)
        //----------------------------------------
        $display("\n--- TEST RDID (9Fh) ---");

        apb_write(32'h0000_2004, 32'h9F);
        apb_write(32'h0000_2000, CTRL(4'd2,0));

        wait_done();
        apb_read(32'h0000_200C);

        //----------------------------------------
        // 4) QUAD READ (6Bh)
        //----------------------------------------
        $display("\n--- TEST QUAD READ (6Bh) ---");

        apb_write(32'h0000_2004, 32'h6B);
        apb_write(32'h0000_2008, 32'h00000000);        // addr
        apb_write(32'h0000_2010, 32'h4);               // length
        apb_write(32'h0000_2000, CTRL(4'd2,1));        // quad enable

        wait_done();
        apb_read(32'h0000_200C);

        //----------------------------------------
        // 5) QUAD WRITE (32h)
        //----------------------------------------
        $display("\n--- TEST QUAD WRITE (32h) ---");

        apb_write(32'h0000_2004, 32'h32);
        apb_write(32'h0000_2008, 32'h00000000);
        apb_write(32'h0000_2010, 32'h4);

        apb_write(32'h0000_2020, 32'hAABBCCDD);

        apb_write(32'h0000_2000, CTRL(4'd2,1));

        wait_done();

        $display("\nALL TESTS DONE\n");
        #100;
        $finish;
    end

    initial begin
        #100000;
        $display("Simulation timeout");
        $finish;
    end

endmodule