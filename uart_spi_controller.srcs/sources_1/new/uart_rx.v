//==============================================================================
// UART Receiver Module
// Master's Level Implementation
// Features: Oversampling, frame error detection, FIFO buffering
//==============================================================================

module uart_rx #(
    parameter CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200,
    parameter FIFO_DEPTH = 16,
    parameter OVERSAMPLE = 16  // Oversample for better reliability
)(
    input wire clk,
    input wire rst_n,
    input wire rx,                     // Serial input
    output reg [7:0] rx_data,          // Received data
    output reg rx_ready,               // Data ready flag
    input wire rx_read,                // Read acknowledge
    output wire fifo_full,
    output wire fifo_empty,
    output reg frame_error             // Frame error flag
);

    // Baud rate generator for oversampling
    localparam BAUD_DIV = CLOCK_FREQ / (BAUD_RATE * OVERSAMPLE);
    reg [$clog2(BAUD_DIV)-1:0] baud_counter;
    reg baud_tick;
    
    // State machine
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;
    
    reg [1:0] state;
    reg [7:0] rx_shift_reg;
    reg [2:0] bit_counter;
    reg [3:0] sample_counter;
    
    // Input synchronization (prevent metastability)
    reg rx_sync1, rx_sync2;
    
    // FIFO
    reg [7:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] fifo_wr_ptr;
    reg [$clog2(FIFO_DEPTH):0] fifo_rd_ptr;
    reg [$clog2(FIFO_DEPTH):0] fifo_count;
    
    assign fifo_full = (fifo_count == FIFO_DEPTH);
    assign fifo_empty = (fifo_count == 0);
    
    // Input synchronization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end
    
    // Baud rate generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (baud_counter == BAUD_DIV - 1) begin
                baud_counter <= 0;
                baud_tick <= 1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick <= 0;
            end
        end
    end
    
    // Receiver state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_shift_reg <= 8'h00;
            bit_counter <= 0;
            sample_counter <= 0;
            rx_ready <= 0;
            frame_error <= 0;
        end else if (baud_tick) begin
            case (state)
                IDLE: begin
                    rx_ready <= 0;
                    frame_error <= 0;
                    if (rx_sync2 == 0) begin  // Start bit detected
                        state <= START;
                        sample_counter <= 0;
                    end
                end
                
                START: begin
                    if (sample_counter == OVERSAMPLE/2 - 1) begin
                        if (rx_sync2 == 0) begin  // Valid start bit
                            state <= DATA;
                            bit_counter <= 0;
                            sample_counter <= 0;
                        end else begin
                            state <= IDLE;  // False start
                        end
                    end else begin
                        sample_counter <= sample_counter + 1;
                    end
                end
                
                DATA: begin
                    if (sample_counter == OVERSAMPLE - 1) begin
                        rx_shift_reg[bit_counter] <= rx_sync2;
                        sample_counter <= 0;
                        if (bit_counter == 7) begin
                            state <= STOP;
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        sample_counter <= sample_counter + 1;
                    end
                end
                
                STOP: begin
                    if (sample_counter == OVERSAMPLE - 1) begin
                        if (rx_sync2 == 1) begin  // Valid stop bit
                            if (!fifo_full) begin
                                fifo_mem[fifo_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= rx_shift_reg;
                                fifo_wr_ptr <= fifo_wr_ptr + 1;
                            end
                            frame_error <= 0;
                        end else begin
                            frame_error <= 1;  // Frame error
                        end
                        state <= IDLE;
                        sample_counter <= 0;
                    end else begin
                        sample_counter <= sample_counter + 1;
                    end
                end
            endcase
        end
    end
    
    // FIFO read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_rd_ptr <= 0;
            rx_data <= 8'h00;
            rx_ready <= 0;
        end else begin
            if (rx_read && !fifo_empty) begin
                rx_data <= fifo_mem[fifo_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
                fifo_rd_ptr <= fifo_rd_ptr + 1;
                rx_ready <= 1;
            end else begin
                rx_ready <= 0;
            end
        end
    end
    
    // FIFO count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= 0;
        end else begin
            case ({(state == STOP && sample_counter == OVERSAMPLE-1 && rx_sync2 == 1 && !fifo_full), 
                   (rx_read && !fifo_empty)})
                2'b10: fifo_count <= fifo_count + 1;
                2'b01: fifo_count <= fifo_count - 1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule