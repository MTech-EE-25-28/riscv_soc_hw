
module tb_soc_top;

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
    $dumpfile("./Verilog/dumps/tb_soc_top.vcd");
    $dumpvars(0, tb_soc_top);
    clk = 0; resetn = 0; pclk = 0; presetn = 0;
    #100;
    resetn = 1; presetn = 1;
    #1000000;
    $display("Testbench timeout.");
    $finish;
end

endmodule