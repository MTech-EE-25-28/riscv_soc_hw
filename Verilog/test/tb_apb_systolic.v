`timescale 1ns / 1ps

module tb_apb_systolic;

reg clk, resetn;
reg pclk, presetn, psel, penable, pwrite;
reg [31:0] paddr, pwdata;
wire [31:0] prdata;
wire pready, pslverr;
wire irq;

apb_systolic #(.BASE_ADDR(32'h0000_2100)) dut (
    .clk(clk), .resetn(resetn),
    .pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
    .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
    .prdata(prdata), .pready(pready), .pslverr(pslverr),
    .irq(irq)
);

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

task apb_read(input [31:0] addr);
    begin
        @(posedge clk); #1;
        psel=1; pwrite=0; penable=0; paddr=addr;
        @(posedge clk); #1;
        penable=1;
        @(posedge clk);
        $display("APB READ [%h] = %h", addr, prdata); #1;
        psel=0; penable=0;
    end
endtask

// Clock generation
always #10 clk = ~clk; // 50MHz
always #10 pclk = ~pclk; // 50MHz

initial begin
    $dumpfile ("./Verilog/dumps/tb_apb_systolic.vcd");
    $dumpvars(0, tb_apb_systolic);
    // Initialize signals
    clk = 0; pclk = 0; resetn = 0;
    presetn = 0; psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
    #100;
    resetn = 1; presetn = 1;

    // simulate some APB transactions to test the accelerator
    // write matrix A
    $display("Writing matrix A...");
    for (integer i = 0; i < 4; i = i + 1) begin
        for (integer j = 0; j < 4; j = j + 1) begin
            apb_write(32'h0000_2104 + (i*4+j)*4, (i*4+j+1)); // A[i][j] = i*4+j+1, MM_MATA=BASE+4
            $display("Wrote A[%0d][%0d] = %0d", i, j, (i*4+j+1));
        end
    end
    // write matrix B
    $display("Writing matrix B...");
    for (integer i = 0; i < 4; i = i + 1) begin
        for (integer j = 0; j < 4; j = j + 1) begin
            apb_write(32'h0000_2144 + (i*4+j)*4, (i*4+j+1)); // B[i][j] = i*4+j+1
            $display("Wrote B[%0d][%0d] = %0d", i, j, (i*4+j+1));
        end
    end
    // start computation
    apb_write(32'h0000_2100, 32'h0000_0001); // set start bit in CTSR

    wait (irq); // wait for computation to complete (done bit set in CTSR and irq asserted)
    $display("Computation done, reading results...");
    // read matrix C
    for (integer i = 0; i < 4; i = i + 1) begin
        for (integer j = 0; j < 4; j = j + 1) begin
            apb_read(32'h0000_2184+(i*4+j)*4); // read C[i][j]
            $display("Read C[%0d][%0d] = %0d", i, j, prdata);
        end
    end

    #1000; // wait for some cycles
    $finish;
end

initial begin
    #100000; // timeout after 100us
    $display("simulation timeout");
    $finish;
end

// always @(posedge clk) begin
//     $monitor("Time: %0t | CTSR: %h | MATA[0]: %h | MATB[0]: %h | MATC[0]: %h | IRQ: %b",
//              $time, dut.CTSR, dut.MATA[0], dut.MATB[0], dut.MATC[0], irq);
// end

endmodule