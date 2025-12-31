//==============================================================================
// SPI Master Testbench
// Tests all 4 SPI modes
//==============================================================================

`timescale 1ns/1ps

module tb_spi_master;

    parameter CLOCK_DIV = 4;
    parameter DATA_WIDTH = 8;
    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg rst_n;
    reg [DATA_WIDTH-1:0] tx_data;
    reg start;
    reg cpol;
    reg cpha;
    wire [DATA_WIDTH-1:0] rx_data;
    wire busy;
    wire done;
    wire sclk;
    wire mosi;
    reg miso;
    wire ss_n;
    
    spi_master #(
        .CLOCK_DIV(CLOCK_DIV),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .start(start),
        .cpol(cpol),
        .cpha(cpha),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .ss_n(ss_n)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Slave simulator
    reg [DATA_WIDTH-1:0] slave_tx_data;
    integer bit_count;
    
    task simulate_slave;
        input [DATA_WIDTH-1:0] data;
        begin
            slave_tx_data = data;
            bit_count = 0;
            
            wait(ss_n == 0);  // Wait for chip select
            
            while(ss_n == 0 && bit_count < DATA_WIDTH) begin
                if (cpol == 0) begin
                    if (cpha == 0) begin
                        @(posedge sclk) miso = slave_tx_data[DATA_WIDTH-1-bit_count];
                        @(negedge sclk) bit_count = bit_count + 1;
                    end else begin
                        @(posedge sclk) bit_count = bit_count + 1;
                        @(negedge sclk) miso = slave_tx_data[DATA_WIDTH-1-bit_count];
                    end
                end else begin
                    if (cpha == 0) begin
                        @(negedge sclk) miso = slave_tx_data[DATA_WIDTH-1-bit_count];
                        @(posedge sclk) bit_count = bit_count + 1;
                    end else begin
                        @(negedge sclk) bit_count = bit_count + 1;
                        @(posedge sclk) miso = slave_tx_data[DATA_WIDTH-1-bit_count];
                    end
                end
            end
        end
    endtask
    
    initial begin
        $dumpfile("spi_master_waveform.vcd");
        $dumpvars(0, tb_spi_master);
        
        rst_n = 0;
        start = 0;
        tx_data = 0;
        miso = 0;
        cpol = 0;
        cpha = 0;
        
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*10);
        
        $display("=== SPI Master Testbench Started ===");
        
        // Test all 4 SPI modes
        for (cpol = 0; cpol <= 1; cpol = cpol + 1) begin
            for (cpha = 0; cpha <= 1; cpha = cpha + 1) begin
                $display("\n--- Testing Mode %d (CPOL=%d, CPHA=%d) ---", 
                         cpol*2 + cpha, cpol, cpha);
                
                tx_data = 8'hA5;
                
                fork
                    begin
                        start = 1;
                        #CLK_PERIOD;
                        start = 0;
                        wait(done);
                        $display("Master TX: 0x%h, RX: 0x%h", 8'hA5, rx_data);
                    end
                    
                    begin
                        simulate_slave(8'h3C);
                    end
                join
                
                if (rx_data == 8'h3C)
                    $display("PASS: Mode %d", cpol*2 + cpha);
                else
                    $display("FAIL: Mode %d - Expected 0x3C, got 0x%h", 
                             cpol*2 + cpha, rx_data);
                
                #(CLK_PERIOD*100);
            end
        end
        
        $display("\n=== SPI Master Tests Completed ===");
        $finish;
    end
    
    initial begin
        #(CLK_PERIOD * 10000);
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule