//==============================================================================
// UART + SPI Controller Top Module
// Master's Level Implementation
// Integrates UART TX/RX and SPI Master/Slave with register interface
//==============================================================================

module uart_spi_controller_top #(
    parameter CLOCK_FREQ = 100_000_000,
    parameter UART_BAUD = 115200,
    parameter SPI_CLK_DIV = 8,
    parameter DATA_WIDTH = 8
)(
    // System signals
    input wire clk,
    input wire rst_n,
    
    // UART interface
    input wire uart_rx,
    output wire uart_tx,
    
    // SPI Master interface
    output wire spi_m_sclk,
    output wire spi_m_mosi,
    input wire spi_m_miso,
    output wire spi_m_ss_n,
    
    // SPI Slave interface
    input wire spi_s_sclk,
    input wire spi_s_mosi,
    output wire spi_s_miso,
    input wire spi_s_ss_n,
    
    // Control/Status
    input wire [7:0] control_reg,
    output wire [7:0] status_reg,
    
    // Data interface
    input wire [7:0] data_in,
    input wire data_wr,
    output wire [7:0] data_out,
    output wire data_rd_valid,
    
    // Interrupts
    output wire uart_rx_interrupt,
    output wire spi_m_done_interrupt,
    output wire spi_s_rx_interrupt
);

    // Control register bit definitions
    wire uart_tx_start = control_reg[0];
    wire spi_m_start = control_reg[1];
    wire spi_cpol = control_reg[2];
    wire spi_cpha = control_reg[3];
    wire protocol_sel = control_reg[4];  // 0=UART, 1=SPI
    
    // UART signals
    wire uart_tx_busy, uart_tx_done;
    wire uart_fifo_full, uart_fifo_empty;
    wire uart_rx_ready, uart_frame_error;
    wire [7:0] uart_rx_data;
    
    // SPI Master signals
    wire spi_m_busy, spi_m_done;
    wire [7:0] spi_m_rx_data;
    
    // SPI Slave signals
    wire spi_s_rx_valid;
    wire [7:0] spi_s_rx_data;
    
    // UART Transmitter
    uart_tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(UART_BAUD)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(data_in),
        .tx_start(uart_tx_start && !protocol_sel),
        .tx(uart_tx),
        .tx_busy(uart_tx_busy),
        .tx_done(uart_tx_done),
        .fifo_full(uart_fifo_full),
        .fifo_empty(uart_fifo_empty)
    );
    
    // UART Receiver
    uart_rx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(UART_BAUD)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(uart_rx_data),
        .rx_ready(uart_rx_ready),
        .rx_read(1'b1),  // Auto-read
        .fifo_full(),
        .fifo_empty(),
        .frame_error(uart_frame_error)
    );
    
    // SPI Master
    spi_master #(
        .CLOCK_DIV(SPI_CLK_DIV),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_spi_master (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(data_in),
        .start(spi_m_start && protocol_sel),
        .cpol(spi_cpol),
        .cpha(spi_cpha),
        .rx_data(spi_m_rx_data),
        .busy(spi_m_busy),
        .done(spi_m_done),
        .sclk(spi_m_sclk),
        .mosi(spi_m_mosi),
        .miso(spi_m_miso),
        .ss_n(spi_m_ss_n)
    );
    
    // SPI Slave
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_spi_slave (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(data_in),
        .tx_valid(data_wr),
        .rx_data(spi_s_rx_data),
        .rx_valid(spi_s_rx_valid),
        .cpol(spi_cpol),
        .cpha(spi_cpha),
        .sclk(spi_s_sclk),
        .mosi(spi_s_mosi),
        .miso(spi_s_miso),
        .ss_n(spi_s_ss_n)
    );
    
    // Output multiplexing
    assign data_out = protocol_sel ? 
                      (spi_m_done ? spi_m_rx_data : spi_s_rx_data) : 
                      uart_rx_data;
    
    assign data_rd_valid = protocol_sel ? 
                           (spi_m_done || spi_s_rx_valid) : 
                           uart_rx_ready;
    
    // Status register
    assign status_reg = {
        uart_frame_error,      // bit 7
        uart_fifo_full,        // bit 6
        spi_s_rx_valid,        // bit 5
        spi_m_done,            // bit 4
        spi_m_busy,            // bit 3
        uart_tx_busy,          // bit 2
        uart_rx_ready,         // bit 1
        uart_tx_done           // bit 0
    };
    
    // Interrupts
    assign uart_rx_interrupt = uart_rx_ready;
    assign spi_m_done_interrupt = spi_m_done;
    assign spi_s_rx_interrupt = spi_s_rx_valid;

endmodule