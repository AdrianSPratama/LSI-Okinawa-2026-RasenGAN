`timescale 1ns / 1ps
`include "reg_output.v"

module tb_reg_output;

    // Parameter
    parameter length = 16;

    // Inputs (Regs in Testbench)
    reg clk;
    reg rst;
    reg [3:0] write_mode;
    reg row_even;
    reg [length-1:0] data_in1;
    reg [length-1:0] data_in2;
    reg [length-1:0] data_in3;
    reg [length-1:0] data_in4;
    reg [length-1:0] data_in5;
    reg [length-1:0] data_in6;
    reg [length-1:0] data_in7;
    reg [length-1:0] data_in8;
    reg [length-1:0] data_in9;

    // Outputs (Wires in Testbench)
    wire [length-1:0] dout;

    // Loop variable
    integer i;

    // Instantiate the Unit Under Test (UUT)
    reg_output #(
        .length(length)
    ) uut (
        .clk(clk), 
        .rst(rst), 
        .write_mode(write_mode), 
        .row_even(row_even), 
        .data_in1(data_in1), 
        .data_in2(data_in2), 
        .data_in3(data_in3), 
        .data_in4(data_in4), 
        .data_in5(data_in5), 
        .data_in6(data_in6), 
        .data_in7(data_in7), 
        .data_in8(data_in8), 
        .data_in9(data_in9), 
        .dout(dout)
    );

    // Clock Generation (Period = 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus Process
    initial begin
        $dumpfile("tb_out.vcd");
        $dumpvars(0, tb_reg_output);

        // 1. Initialize Inputs
        rst = 0; // Active low reset asserted initially
        write_mode = 0;
        row_even = 0;

        // Set Data Inputs 1..9
        data_in1 = 16'd1;
        data_in2 = 16'd2;
        data_in3 = 16'd3;
        data_in4 = 16'd4;
        data_in5 = 16'd5;
        data_in6 = 16'd6;
        data_in7 = 16'd7;
        data_in8 = 16'd8;
        data_in9 = 16'd9;

        // 2. Apply Reset
        #20;
        rst = 1; // Release reset (active low)
        
        // Tunggu sebentar agar sinyal stabil
        @(negedge clk);

        // 3. Loop through all write_modes (0 to 8)
        // Note: Logic case kamu menghandle 0 sampai 8 (4'b1000)
        for (i = 0; i <= 8; i = i + 1) begin
            
            // Set Write Mode
            write_mode = i;
            
            // --- Cycle 1 & 2: Row Even = 0 ---
            // Kita tunggu 2 cycle agar internal register 'coloumn_even' sempat toggle (0->1 atau 1->0)
            row_even = 0;
            repeat (2) @(posedge clk); 

            // --- Cycle 3 & 4: Row Even = 1 ---
            // Kita tunggu 2 cycle lagi dengan row_even aktif
            row_even = 1;
            repeat (2) @(posedge clk);
            
            // Total durasi per write_mode = 4 clock cycles
        end

        // 4. Finish Simulation
        #20;
        $display("Testbench Completed Successfully.");
        $finish;
    end

    // Optional: Monitor changes to console
    initial begin
        $monitor("Time=%0t | Mode=%b | RowEven=%b | coloumn_even_Internal=%b | Dout=%d", 
                 $time, write_mode, row_even, uut.coloumn_even, dout);
    end

endmodule

// 1 1 1 1 1 1 1 1 
// 1 1 1 1 1 1 1 1
// 1 1 1 1 1 1 1 1






