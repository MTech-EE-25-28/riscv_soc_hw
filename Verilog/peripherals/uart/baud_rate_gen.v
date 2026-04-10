
module baud_rate_gen (
    input wire clk,      // System Clock
    input wire reset,
    input wire [15:0] baud_rate_reg,
    output reg baud_tick // High for one clk cycle at baud rate
);

    reg [15:0] counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            baud_tick <= 0;
        end else begin
            if (baud_rate_reg != 0) begin
                if (counter >= baud_rate_reg - 1) begin
                    counter <= 0; baud_tick <= 1;
                end else begin
                    counter <= counter + 1; baud_tick <= 0;
                end
            end else begin // Safe behavior when BRR = 0
                counter <= 0; baud_tick <= 0;
            end
        end
    end

endmodule