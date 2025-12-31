//==============================================================================
// UART Receiver Testbench
//==============================================================================

`timescale 1ns/1ps

module tb_uart_rx;

    parameter CLOCK_FREQ = 100_000_000;
    parameter BAUD_RATE = 115200;
    parameter CLK_PERIOD = 10;
    parameter BIT_PERIOD = 1_000_000_000 / BAUD_RATE;
    
    reg clk;
    reg rst_n;
    reg rx;
    wire [7:0] rx_data;
    wire rx_ready;
    reg rx_read;
    wire fifo_full;
    wire fifo_empty;
    wire frame_error;
    
    uart_rx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .rx_read(rx_read),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .frame_error(frame_error)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rx = 0;
            #BIT_PERIOD;
            
            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #BIT_PERIOD;
            end
            
            // Stop bit
            rx = 1;
            #BIT_PERIOD;
            
            $display("Sent byte: 0x%h at time %t", data, $time);
        end
    endtask
    
    initial begin
        $dumpfile("uart_rx_waveform.vcd");
        $dumpvars(0, tb_uart_rx);
        
        rst_n = 0;
        rx = 1;
        rx_read = 0;
        
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*10);
        
        $display("=== UART RX Testbench Started ===");
        
        // Test 1: Single byte reception
        $display("\n--- Test 1: Single Byte Reception ---");
        send_byte(8'h55);
        wait(rx_ready);
        rx_read = 1;
        #CLK_PERIOD;
        rx_read = 0;
        
        if (rx_data == 8'h55)
            $display("PASS: Test 1 - Received 0x55");
        else
            $display("FAIL: Test 1 - Expected 0x55, got 0x%h", rx_data);
        
        // Test 2: Multiple bytes
        $display("\n--- Test 2: Multiple Bytes ---");
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'hF0);
        
        #(BIT_PERIOD*30);
        
        // Test 3: Frame error (no stop bit)
        $display("\n--- Test 3: Frame Error Detection ---");
        rx = 0;  // Start bit
        #BIT_PERIOD;
        repeat(8) begin
            rx = $random;
            #BIT_PERIOD;
        end
        rx = 0;  // Invalid stop bit
        #BIT_PERIOD;
        rx = 1;
        
        #(BIT_PERIOD*10);
        
        if (frame_error)
            $display("PASS: Test 3 - Frame error detected");
        else
            $display("FAIL: Test 3 - Frame error not detected");
        
        #(BIT_PERIOD*20);
        $display("\n=== UART RX Tests Completed ===");
        $finish;
    end
    
    initial begin
        #(BIT_PERIOD * 500);
        $display("ERROR: Testbench timeout");
        $finish;
    end

endmodule