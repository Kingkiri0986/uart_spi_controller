//==============================================================================
// SPI Master Controller
// Master's Level Implementation
// Features: All 4 SPI modes, configurable clock, full-duplex operation
//==============================================================================

module spi_master #(
    parameter CLOCK_DIV = 8,  // SPI clock = system_clock / (2 * CLOCK_DIV)
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    
    // Control interface
    input wire [DATA_WIDTH-1:0] tx_data,
    input wire start,
    input wire cpol,              // Clock polarity
    input wire cpha,              // Clock phase
    output reg [DATA_WIDTH-1:0] rx_data,
    output reg busy,
    output reg done,
    
    // SPI interface
    output reg sclk,
    output reg mosi,
    input wire miso,
    output reg ss_n               // Slave select (active low)
);

    // State machine
    localparam IDLE = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam FINISH = 2'b10;
    
    reg [1:0] state;
    reg [$clog2(CLOCK_DIV)-1:0] clk_counter;
    reg sclk_toggle;
    reg [$clog2(DATA_WIDTH):0] bit_counter;
    reg [DATA_WIDTH-1:0] tx_shift_reg;
    reg [DATA_WIDTH-1:0] rx_shift_reg;
    reg sclk_int;
    
    // Clock generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= 0;
            sclk_toggle <= 0;
        end else if (state == TRANSFER) begin
            if (clk_counter == CLOCK_DIV - 1) begin
                clk_counter <= 0;
                sclk_toggle <= ~sclk_toggle;
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end else begin
            clk_counter <= 0;
            sclk_toggle <= 0;
        end
    end
    
    // SCLK generation based on CPOL
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_int <= 0;
        end else begin
            if (state == IDLE) begin
                sclk_int <= cpol;  // Idle state matches CPOL
            end else if (state == TRANSFER && clk_counter == CLOCK_DIV - 1) begin
                sclk_int <= ~sclk_int;
            end
        end
    end
    
    assign sclk = sclk_int;
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 0;
            done <= 0;
            ss_n <= 1;
            mosi <= 0;
            rx_data <= 0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    ss_n <= 1;
                    mosi <= 0;
                    sclk <= cpol;
                    
                    if (start) begin
                        tx_shift_reg <= tx_data;
                        rx_shift_reg <= 0;
                        bit_counter <= 0;
                        busy <= 1;
                        ss_n <= 0;
                        state <= TRANSFER;
                        
                        // CPHA = 0: Data valid on first edge
                        if (cpha == 0) begin
                            mosi <= tx_data[DATA_WIDTH-1];
                        end
                    end else begin
                        busy <= 0;
                    end
                end
                
                TRANSFER: begin
                    if (sclk_toggle) begin
                        if (cpha == 0) begin
                            // CPHA = 0: Capture on first edge, change on second
                            if (sclk_int == cpol) begin
                                // First edge: capture
                                rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], miso};
                                bit_counter <= bit_counter + 1;
                            end else begin
                                // Second edge: change
                                if (bit_counter < DATA_WIDTH) begin
                                    tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
                                    mosi <= tx_shift_reg[DATA_WIDTH-1];
                                end else begin
                                    state <= FINISH;
                                end
                            end
                        end else begin
                            // CPHA = 1: Change on first edge, capture on second
                            if (sclk_int == cpol) begin
                                // First edge: change
                                if (bit_counter < DATA_WIDTH) begin
                                    tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
                                    mosi <= tx_shift_reg[DATA_WIDTH-1];
                                end
                            end else begin
                                // Second edge: capture
                                rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], miso};
                                bit_counter <= bit_counter + 1;
                                if (bit_counter == DATA_WIDTH) begin
                                    state <= FINISH;
                                end
                            end
                        end
                    end
                end
                
                FINISH: begin
                    rx_data <= rx_shift_reg;
                    done <= 1;
                    busy <= 0;
                    ss_n <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule