/*******************************************************************************
 * Module: uart_spi_controller_top
 * Description: Top-level integration of UART and SPI controllers
 * Author: Masters Level Design
 * Features:
 *   - Integrated UART TX/RX
 *   - Integrated SPI Master
 *   - Command-based interface via UART
 *   - Status reporting
 *   - Register-based configuration
 ******************************************************************************/

module uart_spi_controller_top #(
    parameter CLK_FREQ = 50_000_000,
    parameter UART_BAUD = 115200,
    parameter SPI_FREQ = 1_000_000,
    parameter SPI_DATA_WIDTH = 8,
    parameter SPI_CPOL = 0,
    parameter SPI_CPHA = 0
)(
    // System signals
    input  wire       clk,
    input  wire       rst_n,
    
    // UART interface
    input  wire       uart_rx,
    output wire       uart_tx,
    
    // SPI interface
    output wire       spi_clk,
    output wire       spi_cs_n,
    output wire       spi_mosi,
    input  wire       spi_miso,
    
    // Status LEDs (optional)
    output wire       led_uart_rx,
    output wire       led_uart_tx,
    output wire       led_spi_active,
    output wire       led_error
);

    // UART signals
    wire [7:0] uart_tx_data;
    wire       uart_tx_valid;
    wire       uart_tx_ready;
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    wire       uart_frame_error;
    
    // SPI signals
    wire [SPI_DATA_WIDTH-1:0] spi_tx_data;
    wire                      spi_tx_valid;
    wire                      spi_tx_ready;
    wire [SPI_DATA_WIDTH-1:0] spi_rx_data;
    wire                      spi_rx_valid;
    
    // Control FSM signals
    reg [2:0]  control_state;
    reg [7:0]  command_reg;
    reg [SPI_DATA_WIDTH-1:0] spi_data_reg;
    reg        execute_spi;
    
    // State definitions
    localparam CTRL_IDLE       = 3'd0;
    localparam CTRL_CMD_RX     = 3'd1;
    localparam CTRL_DATA_RX    = 3'd2;
    localparam CTRL_SPI_EXEC   = 3'd3;
    localparam CTRL_SPI_WAIT   = 3'd4;
    localparam CTRL_TX_RESULT  = 3'd5;
    
    // Command definitions
    localparam CMD_SPI_WRITE   = 8'h01;
    localparam CMD_SPI_READ    = 8'h02;
    localparam CMD_STATUS      = 8'h03;
    localparam CMD_ECHO        = 8'hFF;
    
    // UART TX instantiation
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(UART_BAUD)
    ) uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(uart_tx_data),
        .tx_valid(uart_tx_valid),
        .tx_ready(uart_tx_ready),
        .tx_serial(uart_tx)
    );
    
    // UART RX instantiation
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(UART_BAUD)
    ) uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx_serial(uart_rx),
        .rx_data(uart_rx_data),
        .rx_valid(uart_rx_valid),
        .frame_error(uart_frame_error)
    );
    
    // SPI Master instantiation
    spi_master #(
        .CLK_FREQ(CLK_FREQ),
        .SPI_FREQ(SPI_FREQ),
        .DATA_WIDTH(SPI_DATA_WIDTH),
        .CPOL(SPI_CPOL),
        .CPHA(SPI_CPHA)
    ) spi_master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(spi_tx_data),
        .tx_valid(spi_tx_valid),
        .tx_ready(spi_tx_ready),
        .rx_data(spi_rx_data),
        .rx_valid(spi_rx_valid),
        .spi_clk(spi_clk),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );
    
    // Control FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_state <= CTRL_IDLE;
            command_reg <= 8'h00;
            spi_data_reg <= {SPI_DATA_WIDTH{1'b0}};
            execute_spi <= 1'b0;
        end else begin
            case (control_state)
                CTRL_IDLE: begin
                    execute_spi <= 1'b0;
                    if (uart_rx_valid) begin
                        command_reg <= uart_rx_data;
                        control_state <= CTRL_CMD_RX;
                    end
                end
                
                CTRL_CMD_RX: begin
                    case (command_reg)
                        CMD_SPI_WRITE, CMD_SPI_READ: begin
                            control_state <= CTRL_DATA_RX;
                        end
                        CMD_STATUS, CMD_ECHO: begin
                            control_state <= CTRL_TX_RESULT;
                        end
                        default: begin
                            control_state <= CTRL_IDLE;
                        end
                    endcase
                end
                
                CTRL_DATA_RX: begin
                    if (uart_rx_valid) begin
                        spi_data_reg <= uart_rx_data[SPI_DATA_WIDTH-1:0];
                        control_state <= CTRL_SPI_EXEC;
                    end
                end
                
                CTRL_SPI_EXEC: begin
                    if (spi_tx_ready) begin
                        execute_spi <= 1'b1;
                        control_state <= CTRL_SPI_WAIT;
                    end
                end
                
                CTRL_SPI_WAIT: begin
                    execute_spi <= 1'b0;
                    if (spi_rx_valid) begin
                        control_state <= CTRL_TX_RESULT;
                    end
                end
                
                CTRL_TX_RESULT: begin
                    if (uart_tx_ready) begin
                        control_state <= CTRL_IDLE;
                    end
                end
                
                default: control_state <= CTRL_IDLE;
            endcase
        end
    end
    
    // UART TX data multiplexer
    reg [7:0] tx_data_mux;
    reg       tx_valid_mux;
    
    always @(*) begin
        tx_data_mux = 8'h00;
        tx_valid_mux = 1'b0;
        
        case (control_state)
            CTRL_TX_RESULT: begin
                tx_valid_mux = 1'b1;
                case (command_reg)
                    CMD_SPI_WRITE, CMD_SPI_READ: begin
                        tx_data_mux = spi_rx_data[7:0];
                    end
                    CMD_STATUS: begin
                        tx_data_mux = {4'b0, uart_frame_error, ~spi_cs_n, uart_tx_ready, uart_rx_valid};
                    end
                    CMD_ECHO: begin
                        tx_data_mux = command_reg;
                    end
                    default: tx_data_mux = 8'hFF;
                endcase
            end
            default: begin
                tx_valid_mux = 1'b0;
                tx_data_mux = 8'h00;
            end
        endcase
    end
    
    assign uart_tx_data = tx_data_mux;
    assign uart_tx_valid = tx_valid_mux;
    
    // SPI control
    assign spi_tx_data = {{(SPI_DATA_WIDTH-8){1'b0}}, spi_data_reg};
    assign spi_tx_valid = execute_spi;
    
    // LED indicators
    reg uart_rx_activity, uart_tx_activity, spi_activity;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx_activity <= 1'b0;
            uart_tx_activity <= 1'b0;
            spi_activity <= 1'b0;
        end else begin
            uart_rx_activity <= uart_rx_valid;
            uart_tx_activity <= uart_tx_valid & uart_tx_ready;
            spi_activity <= ~spi_cs_n;
        end
    end
    
    assign led_uart_rx = uart_rx_activity;
    assign led_uart_tx = uart_tx_activity;
    assign led_spi_active = spi_activity;
    assign led_error = uart_frame_error;

endmodule