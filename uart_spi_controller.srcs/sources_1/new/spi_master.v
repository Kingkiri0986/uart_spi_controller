/*******************************************************************************
 * Module: spi_master
 * Description: SPI Master Controller supporting all 4 SPI modes
 * Author: Masters Level Design
 * Features:
 *   - Supports all 4 SPI modes (CPOL, CPHA combinations)
 *   - Configurable clock frequency
 *   - Variable data width (8/16/32 bits)
 *   - Ready/valid handshaking interface
 *   - MSB first transmission
 *   - Fully synthesizable
 ******************************************************************************/

module spi_master #(
    parameter CLK_FREQ = 50_000_000,   // System clock frequency in Hz
    parameter SPI_FREQ = 1_000_000,    // SPI clock frequency in Hz
    parameter DATA_WIDTH = 8,          // Data width (8, 16, or 32)
    parameter CPOL = 0,                // Clock polarity
    parameter CPHA = 0                 // Clock phase
)(
    input  wire                  clk,        // System clock
    input  wire                  rst_n,      // Active low reset
    // Control interface
    input  wire [DATA_WIDTH-1:0] tx_data,    // Data to transmit
    input  wire                  tx_valid,   // Start transmission
    output reg                   tx_ready,   // Ready for new data
    output reg  [DATA_WIDTH-1:0] rx_data,    // Received data
    output reg                   rx_valid,   // Received data valid
    // SPI interface
    output reg                   spi_clk,    // SPI clock
    output reg                   spi_cs_n,   // Chip select (active low)
    output reg                   spi_mosi,   // Master out, slave in
    input  wire                  spi_miso    // Master in, slave out
);

    // Calculate clock divider
    localparam DIVISOR = CLK_FREQ / (2 * SPI_FREQ);
    localparam DIVISOR_WIDTH = $clog2(DIVISOR);
    localparam BIT_COUNT_WIDTH = $clog2(DATA_WIDTH);
    
    // State machine states
    localparam IDLE     = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam FINISH   = 2'b10;
    
    // Internal registers
    reg [1:0]                  state, next_state;
    reg [DIVISOR_WIDTH-1:0]    clk_div_counter;
    reg [BIT_COUNT_WIDTH:0]    bit_counter;
    reg [DATA_WIDTH-1:0]       tx_shift_reg;
    reg [DATA_WIDTH-1:0]       rx_shift_reg;
    reg                        spi_clk_en;
    reg                        spi_clk_next;
    reg                        clk_edge_toggle;
    reg                        miso_sync1, miso_sync2;
    
    // MISO synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            miso_sync1 <= 1'b0;
            miso_sync2 <= 1'b0;
        end else begin
            miso_sync1 <= spi_miso;
            miso_sync2 <= miso_sync1;
        end
    end
    
    // Clock divider for SPI clock generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_counter <= 0;
            clk_edge_toggle <= 1'b0;
        end else begin
            if (!spi_clk_en) begin
                clk_div_counter <= 0;
                clk_edge_toggle <= 1'b0;
            end else if (clk_div_counter == DIVISOR - 1) begin
                clk_div_counter <= 0;
                clk_edge_toggle <= 1'b1;
            end else begin
                clk_div_counter <= clk_div_counter + 1;
                clk_edge_toggle <= 1'b0;
            end
        end
    end
    
    // SPI clock generation with CPOL support
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk <= CPOL[0];
        end else begin
            if (!spi_clk_en) begin
                spi_clk <= CPOL[0];
            end else if (clk_edge_toggle) begin
                spi_clk <= spi_clk_next;
            end
        end
    end
    
    always @(*) begin
        spi_clk_next = ~spi_clk;
    end
    
    // Determine sampling and shifting edges based on CPHA
    wire sample_edge = (CPHA == 0) ? ~spi_clk & clk_edge_toggle : spi_clk & clk_edge_toggle;
    wire shift_edge  = (CPHA == 0) ? spi_clk & clk_edge_toggle : ~spi_clk & clk_edge_toggle;
    
    // State machine sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // State machine combinational logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (tx_valid)
                    next_state = TRANSFER;
            end
            
            TRANSFER: begin
                if (bit_counter == DATA_WIDTH && shift_edge)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // SPI clock enable
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk_en <= 1'b0;
        end else begin
            case (state)
                IDLE:     spi_clk_en <= 1'b0;
                TRANSFER: spi_clk_en <= 1'b1;
                FINISH:   spi_clk_en <= 1'b0;
                default:  spi_clk_en <= 1'b0;
            endcase
        end
    end
    
    // Chip select generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_cs_n <= 1'b1;
        end else begin
            case (state)
                IDLE:     spi_cs_n <= 1'b1;
                TRANSFER: spi_cs_n <= 1'b0;
                FINISH:   spi_cs_n <= 1'b1;
                default:  spi_cs_n <= 1'b1;
            endcase
        end
    end
    
    // Bit counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= 0;
        end else begin
            if (state == IDLE) begin
                bit_counter <= 0;
            end else if (state == TRANSFER && shift_edge) begin
                bit_counter <= bit_counter + 1;
            end
        end
    end
    
    // Load and shift TX data (MSB first)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            if (state == IDLE && tx_valid) begin
                tx_shift_reg <= tx_data;
            end else if (state == TRANSFER && shift_edge) begin
                tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
            end
        end
    end
    
    // MOSI output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_mosi <= 1'b0;
        end else begin
            if (state == TRANSFER)
                spi_mosi <= tx_shift_reg[DATA_WIDTH-1];
            else
                spi_mosi <= 1'b0;
        end
    end
    
    // Sample and shift RX data (MSB first)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            if (state == TRANSFER && sample_edge) begin
                rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], miso_sync2};
            end
        end
    end
    
    // Output received data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= {DATA_WIDTH{1'b0}};
            rx_valid <= 1'b0;
        end else begin
            if (state == FINISH) begin
                rx_data <= rx_shift_reg;
                rx_valid <= 1'b1;
            end else begin
                rx_valid <= 1'b0;
            end
        end
    end
    
    // Ready signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_ready <= 1'b1;
        end else begin
            tx_ready <= (state == IDLE);
        end
    end

endmodule