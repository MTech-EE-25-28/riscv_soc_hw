
module tb_free_run;


reg clk, resetn;
reg pclk, presetn;

wire pwm_out0, pwm_out1;
wire [31:0] gpio_pad;
wire tx, rx;
assign rx = tx;

soc_top dut (
    .clk(clk), .rst_n(resetn),
    .pclk(pclk), .presetn(presetn),
    .pwm_out0(pwm_out0), .pwm_out1(pwm_out1),
    .gpio_pad(gpio_pad),
    .rx(rx), .tx(tx)
);

always #10 clk = ~clk;
always #10 pclk = ~pclk;

initial begin
    $dumpfile("./Verilog/dumps/tb_free_run.vcd");
    $dumpvars(0, tb_free_run);
    clk = 0; resetn = 0; pclk = 0; presetn = 0;
    #100;
    resetn = 1; presetn = 1;
    // run for 10s (very huge)
    $display("Starting free run test...");
    // 1s -> 1000000000ns, so 10s -> 10000000000ns
    #1000000000;
    $display("1 second elapsed.");
    #1000000000;
    $display("2 second elapsed.");
    #1000000000;
    $display("3 second elapsed.");
    #1000000000;
    $display("4 second elapsed.");
    #1000000000;
    $display("5 second elapsed.");
    #100;
    $display("Testbench timeout.");
    $finish;
end

endmodule