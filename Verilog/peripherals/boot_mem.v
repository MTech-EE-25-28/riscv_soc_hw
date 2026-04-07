`timescale 1ns / 1ps
// ============================================================
// 1st address 
module boot_uart_mem #(
    parameter UART_BASE_ADDR  = 32'h0000_2040,
    parameter UART_baud_rate  = 32'd4,
    parameter UART_parity_sel = 1'b1,    // 0 = even, 1 = odd  ? CR[5]
    parameter UART_parity_en  = 1'b1,    // parity enable       ? CR[4]
    
    parameter MEM_write_addr  = 32'h0000_3000 // instruction mem controller address
)(
    input         clk,
    input         uart_select,  // activate UART path when high
    output reg    reset_cpu,    // CPU reset - active-low during boot, high when done
    input         main_reset,   // total MCU reset, active-low
    // APB master interface
    input      [31:0] p_r_data,  // APB read data from slave (uart_top.prdata)
    output reg [31:0] p_addr,    // APB address
    output reg [31:0] p_w_data,  // APB write data
    output reg        psel,
    output reg        penable,
    input             pready,    // ignored (uart_top ready)
    output reg        p_write,
    input             pslverr,   // ignored
    output reg        presetn,    // APB reset driven to uart_top (active-low)
    
    // APB memory
    input      [31:0] mem_r_data,  // input signal which can be ignored for now
    output reg [31:0] mem_addr,
    output     [31:0] mem_w_data,  // APB write data
    output reg        mem_sel,
    output reg        mem_enable,
    input             mem_ready,    // ignored (uart_top ready)
    output reg        mem_write,
    input             mem_slverr,   // ignored
    output            mem_resetn
);

    //  State encoding
    localparam IDLE             = 4'b0000;
    localparam UART_BRR_set     = 4'b1001;
    localparam UART_control_reg = 4'b1010;
    localparam UART_receive     = 4'b1011;
    localparam finished         = 4'b1111;
    
    //  Address offsets (relative to UART_BASE_ADDR)
    localparam RDR_SR_addr      = 8'h00;    // offset 0x00 : {15'b0, RDR[8:0], SR[7:0]}  - read-only from UART
    localparam control_reg_addr = 8'h0c;    // control reg address of UART
    localparam baud_rate_addr   = 8'h10;    // Baud Rate address of UART
    localparam transfer_addr    = 8'h08;    // unused by bootloader

    
    reg [3:0]  curr_state, next_state;
    reg [31:0] mem_send_data;        // 4 received bytes packed MSB-first
    reg [1:0]  counter;              // counts 0?3 for the 4 bytes per word
    reg        mem_send_fully_loaded; // set when 4th byte is loaded
    reg [3:0]  counter_2;            // idle-cycle counter for finish detection
    
    assign mem_w_data = (mem_write)? mem_send_data : 32'hfaaa_aa11;
    assign mem_resetn = presetn;
    
    //  Next-state logic (combinational)
    always @(*) begin
        case (curr_state)
            IDLE             : next_state = uart_select ? UART_BRR_set     : IDLE;
            UART_BRR_set     : next_state = (pready)? UART_control_reg     : UART_BRR_set; // one cycle
            UART_control_reg : next_state = (pready)? UART_receive         : UART_control_reg;     // one cycle

            // p_r_data[3] = idle_flag (SR[3]).
            // Stay in UART_receive until UART has been idle for 5 consecutive
            UART_receive     : next_state = (p_r_data[3] && counter_2 == 4'd5) ? finished : UART_receive;
            finished         : next_state = (~main_reset) ? IDLE : finished;   // Once finished: stay until main_reset is asserted (active-low)

            default          : next_state = IDLE;
        endcase
    end

    //  Output / register logic (sequential)
    always @(posedge clk or negedge main_reset) begin
        if (~main_reset) begin
            // Full reset - hold CPU and peripherals in reset
            reset_cpu             <= 1'b0;  // active-low: CPU held in reset
            presetn               <= 1'b0;  // APB reset asserted to uart_top
            curr_state            <= IDLE;
            counter               <= 2'b00;
            counter_2             <= 4'd0;
            mem_send_data         <= 32'd0;
            mem_send_fully_loaded <= 1'b0;
            p_write               <= 1'b0;
            penable               <= 1'b0;
            psel                  <= 1'b0;
            p_w_data              <= 32'd0;
            p_addr                <= 32'hFFFF_FFFF;
            
            //memory
            mem_addr              <= 32'hFFFF_FFFF;
            mem_sel               <= 1'b0;
            mem_enable            <= 1'b0;
            mem_write             <= 1'b0; 
            
        end
        else begin
            curr_state <= next_state;
            //mem_r_data -- input signal which can be ignored for now
            mem_addr            <= MEM_write_addr;
            //mem_w_data -- connected directly to mem_send_data
            mem_sel             <= 1'b1;
            mem_enable          <= 1'b1;
            //mem_ready -- input signal -- important , 
            //present inside case -- //mem_write   <= 1'b0; // memory write enable -- very important
            //mem_slverr -- input signal -- ignore
            //mem_resetn -- connected directly to UART reset 
        
            case (curr_state)
                 default :  mem_write     <= 1'b0; // memory write enable -- very important  
                IDLE : begin
                    presetn               <= 1'b1; // release APB reset - both UART, MEM
                    p_write               <= 1'b0;
                    penable               <= 1'b0;
                    
                    mem_write             <= 1'b0;
                    
                    psel                  <= 1'b0;
                    p_w_data              <= 32'd0;
                    p_addr                <= 32'hFFFF_FFFF;
                    counter               <= 2'b00;
                    counter_2             <= 4'd0;
                    mem_send_data         <= 32'd0;
                    mem_send_fully_loaded <= 1'b0;
                end
                UART_BRR_set : begin //baud rate set
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    
                    mem_write <= 1'b0;
                    
                    psel     <= 1'b1;
                    p_w_data <= UART_baud_rate;
                    p_addr   <= UART_BASE_ADDR + baud_rate_addr;
                end
                //  UART control register configuration
                // [7:6] = 2'b00(interrupts disabled) [5]= UART_parity_sel(PS: 0=even,1=odd), [4]=UART_parity_en(PCE), 
                // [3]=1'b0(M: 8-bit mode), [2]= 1'b1 (RE: receive enable), [1]=1'b0 (TE: transmit disable), [0]=1'b1 (UE: UART enable)
                UART_control_reg : begin
                    p_write  <= 1'b1;
                    penable  <= 1'b1;
                    
                    mem_write <= 1'b0;
                    
                    psel     <= 1'b1;
                    p_w_data <= {24'h00_0000, 2'b00, UART_parity_sel, UART_parity_en, 4'b0101};
                    p_addr   <= UART_BASE_ADDR + control_reg_addr;
                end

                // ----------------------------------------------
                //    prdata = {15'b0, RDR[8:0], SR[7:0]}
                //      p_r_data[1]  = rxne_flag  ? new byte ready
                //      p_r_data[3]  = idle_flag  ? no activity on RX
                //      p_r_data[15:8] = received byte (RDR[7:0])

                UART_receive : begin
                    p_write  <= 1'b0; // no write to uart
                    penable  <= 1'b1;
                    psel     <= 1'b1;
                    p_w_data <= mem_send_data;
                    p_addr   <= UART_BASE_ADDR + RDR_SR_addr;

                    // counter_2 -- Idle counter 
                    if (p_r_data[3])  counter_2 <= counter_2 + 1;       // idle_flag=1
                    else   counter_2 <= 4'd0;
                    
                    // After a full word is written, reset for next word
                    if (mem_send_fully_loaded && mem_write) begin
                        mem_send_fully_loaded <= 1'b0;
                        counter               <= 2'b00;
                        mem_write             <= 1'b0;
                    end
                    else if(mem_send_fully_loaded && (!mem_write) ) begin
                        mem_write <= (mem_ready) ? 1'b1 : 1'b0;
                    end
                    case (counter)
                        2'b00 : begin
                            if (p_r_data[1]) begin   // rxne_flag set
                                mem_send_data[31:24]  <= p_r_data[15:8];       //    counter=0 ? mem_send_data[31:24]
                                counter               <= counter + 1;
                                mem_send_fully_loaded <= 1'b0;
                            end
                        end 
                        2'b01 : begin
                            if (p_r_data[1]) begin
                                mem_send_data[23:16] <= p_r_data[15:8];
                                counter              <= counter + 1;
                            end
                        end 
                        2'b10 : begin
                            if (p_r_data[1]) begin
                                mem_send_data[15:8] <= p_r_data[15:8];
                                counter             <= counter + 1;
                            end
                        end 
                        2'b11 : begin
                            if (p_r_data[1]) begin
                                mem_send_data[7:0]    <= p_r_data[15:8];
                                counter               <= counter + 1; // wraps to 2'b00
                                mem_send_fully_loaded <= 1'b1;
                            end
                        end
                    endcase
                end // UART_receive

                finished : begin
                    reset_cpu <= 1'b1;
                end
            endcase
        end
    end
endmodule