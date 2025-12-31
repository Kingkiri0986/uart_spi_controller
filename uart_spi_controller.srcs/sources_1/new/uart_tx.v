//==============================================================================
// UART Transmitter Module
// Master's Level Implementation
// Features: Configurable baud rate, FIFO buffering, FSM-based control
//==============================================================================

module uart_tx #(
    parameter CLOCK_FREQ = 100_000_000,  // 100 MHz system clock
    parameter BAUD_RATE = 115200,
    parameter FIFO_DEPTH = 16
)(
    input wire clk,                    // System clock
    input wire rst_n,                  // Active-low reset
    input wire [7:0] tx_data,          // Data to transmit
    input wire tx_start,               // Start transmission
    output reg tx,                     // Serial output
    output wire tx_busy,               // Transmitter busy flag
    output wire tx_done,               // Transmission complete
    output wire fifo_full,             // FIFO full flag
    output wire fifo_empty             // FIFO empty flag
);

    // Baud rate generator
    localparam BAUD_DIV = CLOCK_FREQ / BAUD_RATE;
    reg [$clog2(BAUD_DIV)-1:0] baud_counter;
    reg baud_tick;
    
    // State machine states
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;
    localparam DONE  = 3'b100;
    
    reg [2:0] state, next_state;
    reg [7:0] tx_shift_reg;
    reg [2:0] bit_counter;
    reg tx_busy_reg;
    reg tx_done_reg;
    
    // FIFO signals
    reg [7:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] fifo_wr_ptr;
    reg [$clog2(FIFO_DEPTH):0] fifo_rd_ptr;
    reg [$clog2(FIFO_DEPTH):0] fifo_count;
    wire fifo_wr_en;
    wire fifo_rd_en;
    reg [7:0] fifo_data_out;
    
    // FIFO control
    assign fifo_full = (fifo_count == FIFO_DEPTH);
    assign fifo_empty = (fifo_count == 0);
    assign fifo_wr_en = tx_start && !fifo_full;
    assign fifo_rd_en = (state == IDLE) && !fifo_empty && !tx_busy_reg;
    
    // FIFO write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_wr_ptr <= 0;
        end else if (fifo_wr_en) begin
            fifo_mem[fifo_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= tx_data;
            fifo_wr_ptr <= fifo_wr_ptr + 1;
        end
    end
    
    // FIFO read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_rd_ptr <= 0;
            fifo_data_out <= 8'h00;
        end else if (fifo_rd_en) begin
            fifo_data_out <= fifo_mem[fifo_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
            fifo_rd_ptr <= fifo_rd_ptr + 1;
        end
    end
    
    // FIFO count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= 0;
        end else begin
            case ({fifo_wr_en, fifo_rd_en})
                2'b10: fifo_count <= fifo_count + 1;
                2'b01: fifo_count <= fifo_count - 1;
                default: fifo_count <= fifo_count;
            endcase
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
    
    // State machine - sequential
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else if (baud_tick)
            state <= next_state;
    end
    
    // State machine - combinational
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (!fifo_empty)
                    next_state = START;
            end
            START: next_state = DATA;
            DATA: begin
                if (bit_counter == 7)
                    next_state = STOP;
            end
            STOP: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx <= 1'b1;
            tx_shift_reg <= 8'h00;
            bit_counter <= 0;
            tx_busy_reg <= 0;
            tx_done_reg <= 0;
        end else if (baud_tick) begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_done_reg <= 0;
                    if (!fifo_empty) begin
                        tx_shift_reg <= fifo_data_out;
                        tx_busy_reg <= 1;
                    end else begin
                        tx_busy_reg <= 0;
                    end
                end
                START: begin
                    tx <= 1'b0;  // Start bit
                    bit_counter <= 0;
                end
                DATA: begin
                    tx <= tx_shift_reg[bit_counter];
                    bit_counter <= bit_counter + 1;
                end
                STOP: begin
                    tx <= 1'b1;  // Stop bit
                end
                DONE: begin
                    tx <= 1'b1;
                    tx_busy_reg <= 0;
                    tx_done_reg <= 1;
                end
            endcase
        end
    end
    
    assign tx_busy = tx_busy_reg;
    assign tx_done = tx_done_reg;

endmodule