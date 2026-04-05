module qspi_clk_gen (
    input  wire       clk,
    input  wire       resetn,
    input  wire       enable,
    input  wire [3:0] clk_div,

    output reg        sck,
    output reg        sck_rise,
    output reg        sck_fall
);

    reg [3:0] div_cnt;
    wire [3:0] div_val = (clk_div == 0) ? 4'd1 : clk_div;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            div_cnt  <= 0;
            sck      <= 0;
            sck_rise <= 0;
            sck_fall <= 0;
        end else begin
            sck_rise <= 0;
            sck_fall <= 0;

            if (enable) begin
                if (div_cnt == div_val - 1) begin
                    div_cnt <= 0;

                    // Edge detection (safe)
                    if (sck == 0)
                        sck_rise <= 1;
                    else
                        sck_fall <= 1;

                    sck <= ~sck;

                end else begin
                    div_cnt <= div_cnt + 1;
                end
            end else begin
                div_cnt <= 0;
                sck     <= 0;  // CPOL = 0
            end
        end
    end

endmodule