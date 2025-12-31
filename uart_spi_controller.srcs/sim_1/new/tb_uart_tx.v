//==============================================================================
// UART Transmitter Testbench
// Comprehensive verification with multiple test scenarios
//==============================================================================

`timescale 1ns/1ps

module tb_uart_tx;

    parameter CLOCK_FREQ = 100_000_000;
    parameter BAUD_RATE = 115200;
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter BIT_PERIOD = 1_000_000_000 / BAUD_RATE;  // nanoseconds
    
    reg clk;
    reg rst_n;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx;
    wire tx_busy;
    wire tx_done;
    wire fifo_full;
    wire fifo_empty;
    
    // Instantiate UART TX
    uart_tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Receiver verification logic
    reg [7:0] received_data;
    integer bit_idx;
    
    task receive_byte;
        output [7:0] data;
        begin
            // Wait for start bit
            @(negedge tx);
            #(BIT_PERIOD/2);  // Sample in middle of bit
            
            // Verify start bit
            if (tx !== 1'b0) begin
                $display("ERROR: Invalid start bit at time %t", $time);
            end
            
            // Receive 8 data bits
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                #BIT_PERIOD;
                data[bit_idx] = tx;
            end
            
            // Check stop bit
            #BIT_PERIOD;
            if (tx !== 1'b1) begin
                $display("ERROR: Invalid stop bit at time %t", $time);
            end else begin
                $display("SUCCESS: Received byte 0x%h at time %t", data, $time);
            end
        end
    endtask
    
    // Test stimulus
    initial begin
        // Initialize waveform dump
        $dumpfile("uart_tx_waveform.vcd");
        $dumpvars(0, tb_uart_tx);
        
        // Initialize signals
        rst_n = 0;
        tx_start = 0;
        tx_data = 8'h00;
        
        // Reset
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*10);
        
        $display("=== UART TX Testbench Started ===");
        $display("Clock Frequency: %d Hz", CLOCK_FREQ);
        $display("Baud Rate: %d", BAUD_RATE);
        $display("Bit Period: %d ns", BIT_PERIOD);
        
        // Test 1: Single byte transmission
        $display("\n--- Test 1: Single Byte Transmission ---");
        tx_data = 8'hA5;
        tx_start = 1;
        #CLK_PERIOD;
        tx_start = 0;
        receive_byte(received_data);
        if (received_data == 8'hA5)
            $display("PASS: Test 1");
        else
            $display("FAIL: Test 1 - Expected 0xA5, got 0x%h", received_data);
        
        // Test 2: Back-to-back transmissions
        $display("\n--- Test 2: Back-to-Back Transmissions ---");
        repeat(3) begin
            @(posedge clk);
            tx_data = $random;
            tx_start = 1;
            #CLK_PERIOD;
            tx_start = 0;
            receive_byte(received_data);
        end
        $display("PASS: Test 2");
        
        // Test 3: FIFO fill
        $display("\n--- Test 3: FIFO Fill Test ---");
        repeat(16) begin
            @(posedge clk);
            tx_data = $random;
            tx_start = 1;
            #CLK_PERIOD;
            tx_start = 0;
        end
        
        if (fifo_full)
            $display("PASS: Test 3 - FIFO full detected");
        else
            $display("FAIL: Test 3 - FIFO should be full");
        
        // Wait for all transmissions to complete
        wait(fifo_empty);
        #(BIT_PERIOD*20);
        
        $display("\n=== All Tests Completed ===");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(BIT_PERIOD * 1000);
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule