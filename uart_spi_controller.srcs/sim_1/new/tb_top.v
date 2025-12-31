//==============================================================================
// Top Module Integrated Testbench
// Tests complete system with UART and SPI
//==============================================================================

`timescale 1ns/1ps

module tb_top;

    parameter CLOCK_FREQ = 100_000_000;
    parameter UART_BAUD = 115200;
    parameter CLK_PERIOD = 10;
    parameter BIT_PERIOD = 1_000_000_000 / UART_BAUD;
    
    reg clk;
    reg rst_n;
    reg uart_rx;
    wire uart_tx;
    wire spi_m_sclk;
    wire spi_m_mosi;
    reg spi_m_miso;
    wire spi_m_ss_n;
    reg spi_s_sclk;
    reg spi_s_mosi;
    wire spi_s_miso;
    reg spi_s_ss_n;
    reg [7:0] control_reg;
    wire [7:0] status_reg;
    reg [7:0] data_in;
    reg data_wr;
    wire [7:0] data_out;
    wire data_rd_valid;
    wire uart_rx_interrupt;
    wire spi_m_done_interrupt;
    wire spi_s_rx_interrupt;
    
    uart_spi_controller_top #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .UART_BAUD(UART_BAUD)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .spi_m_sclk(spi_m_sclk),
        .spi_m_mosi(spi_m_mosi),
        .spi_m_miso(spi_m_miso),
        .spi_m_ss_n(spi_m_ss_n),
        .spi_s_sclk(spi_s_sclk),
        .spi_s_mosi(spi_s_mosi),
        .spi_s_miso(spi_s_miso),
        .spi_s_ss_n(spi_s_ss_n),
        .control_reg(control_reg),
        .status_reg(status_reg),
        .data_in(data_in),
        .data_wr(data_wr),
        .data_out(data_out),
        .data_rd_valid(data_rd_valid),
        .uart_rx_interrupt(uart_rx_interrupt),
        .spi_m_done_interrupt(spi_m_done_interrupt),
        .spi_s_rx_interrupt(spi_s_rx_interrupt)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            uart_rx = 0;  // Start bit
            #BIT_PERIOD;
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #BIT_PERIOD;
            end
            uart_rx = 1;  // Stop bit
            #BIT_PERIOD;
        end
    endtask
    
    initial begin
        $dumpfile("top_module_waveform.vcd");
        $dumpvars(0, tb_top);
        
        // Initialize
        rst_n = 0;
        uart_rx = 1;
        control_reg = 0;
        data_in = 0;
        data_wr = 0;
        spi_m_miso = 0;
        spi_s_sclk = 0;
        spi_s_mosi = 0;
        spi_s_ss_n = 1;
        
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*10);
        
        $display("=== Top Module Integration Test ===");
        
        // Test 1: UART TX
        $display("\n--- Test 1: UART Transmission ---");
        control_reg = 8'b00000001;  // Enable UART TX, protocol_sel=0
        data_in = 8'hAB;
        #CLK_PERIOD;
        control_reg = 8'b00000000;
        
        #(BIT_PERIOD*15);
        $display("UART TX Test completed");
        
        // Test 2: UART RX
        $display("\n--- Test 2: UART Reception ---");
        uart_send_byte(8'h5A);
        wait(uart_rx_interrupt);
        $display("Received UART data: 0x%h", data_out);
        
        #(CLK_PERIOD*100);
        
        // Test 3: SPI Master
        $display("\n--- Test 3: SPI Master Transmission ---");
        control_reg = 8'b00010010;  // SPI master start, protocol_sel=1
        data_in = 8'hCD;
        
        fork
            begin
                #CLK_PERIOD;
                control_reg = 8'b00010000;
                wait(spi_m_done_interrupt);
                $display("SPI Master completed, RX: 0x%h", data_out);
            end
            begin
                // Simulate SPI slave response
                wait(spi_m_ss_n == 0);
                repeat(8) begin
                    @(posedge spi_m_sclk);
                    spi_m_miso = $random;
                end
            end
        join
        
        #(CLK_PERIOD*100);
            
        $display("\n=== All Integration Tests Completed ===");
        $display("Status Register: 0b%b", status_reg);
        $finish;
    end
    
    initial begin
        #(BIT_PERIOD * 1000);
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule