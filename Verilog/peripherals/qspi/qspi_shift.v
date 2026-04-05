    module qspi_shift (
    input  wire        clk,
    input  wire        resetn,

    // Direction
    input  wire        dir_rx,     // 0 = TX, 1 = RX
    input  wire        quad_tx,
    input  wire        quad_rx,

    // Chunk control
    input  wire        load_chunk,
    input  wire [31:0] chunk_data,
    input  wire [5:0]  chunk_cycles,

    // SCLK edges
    input  wire        sck_rise,
    input  wire        sck_fall,

    // IO bus
    inout  wire [3:0]  io,

    // TX streaming
    output reg         data_req,

    // RX streaming
    output reg  [7:0]  rx_byte,
    output reg         data_ready,

    // Status
    output reg         busy,
    output reg         done
);

    //----------------------------------------------------
    // IO driving
    //----------------------------------------------------
    reg [3:0] io_out;
    reg       io_oe;

    assign io = io_oe ? io_out : 4'bz;
    wire [3:0] io_in = io;

    //----------------------------------------------------
    // Shift registers
    //----------------------------------------------------
    reg [31:0] shreg;
    reg [5:0]  cycles_left;
    reg [5:0]  chunk_cycles_latched;
    reg [7:0]  rxbuf;
    reg        half_cycle;
    //----------------------------------------------------
    // Sequential logic
    //----------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin

            shreg       <= 0;
            cycles_left <= 0;
            chunk_cycles_latched <= 0;

            busy        <= 0;
            done        <= 0;

            data_req    <= 0;
            data_ready  <= 0;
            rx_byte     <= 0;

            io_out      <= 0;
            io_oe       <= 0;

            rxbuf       <= 0;
            half_cycle  <= 0;
        end else begin

            // default strobes
            done       <= 0;
            data_req   <= 0;
            data_ready <= 0;

            //------------------------------------------------
            // LOAD NEW CHUNK
            //------------------------------------------------
            if (load_chunk) begin

                shreg       <= chunk_data;
                cycles_left <= chunk_cycles;
                chunk_cycles_latched <= chunk_cycles;
                
                busy       <= 1;
                half_cycle <= 0;
                rxbuf      <= 0;

                io_oe <= !dir_rx;

                if (!dir_rx) begin
                    if (quad_tx)
                        io_out <= chunk_data[31:28];
                    else
                        io_out <= {3'b000, chunk_data[31]};
                end
            end

            //------------------------------------------------
            // RX Sampling (SCLK Rising Edge)
            //------------------------------------------------
            if (busy && dir_rx && sck_rise && cycles_left != 0) begin

                if (quad_rx) begin

                    rxbuf <= {rxbuf[3:0], io_in};

                    if (half_cycle) begin
                        rx_byte    <= {rxbuf[3:0], io_in};
                        data_ready <= 1;
                    end

                    half_cycle <= ~half_cycle;

                end else begin

                    rxbuf <= {rxbuf[6:0], io_in[1]};

                    if (cycles_left[2:0] == 1) begin
                        rx_byte    <= {rxbuf[6:0], io_in[1]};
                        data_ready <= 1;
                    end

                end
            end

            //------------------------------------------------
            // TX Shifting (SCLK Falling Edge)
            //------------------------------------------------
            if (busy && !dir_rx && sck_fall && cycles_left != 0) begin

                if (quad_tx) begin
                    shreg  <= {shreg[27:0], 4'b0};
                    io_out <= shreg[27:24];
                end else begin
                    shreg  <= {shreg[30:0], 1'b0};
                    io_out <= {3'b000, shreg[30]};
                end
            end

            //------------------------------------------------
            // Cycle Counter
            //------------------------------------------------
            if (busy && sck_fall && cycles_left != 0) begin

                cycles_left <= cycles_left - 1;

                // Request next TX data early
                if (!dir_rx && cycles_left == (chunk_cycles_latched - 1))
                    data_req <= 1;

                if (cycles_left == 1) begin
                    busy <= 0;
                    done <= 1;
                    io_oe <= 0;
                end

            end

        end
    end

endmodule